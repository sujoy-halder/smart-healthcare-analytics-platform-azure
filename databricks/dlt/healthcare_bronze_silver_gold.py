# Databricks notebook source
import dlt
from pyspark.sql import functions as F
from pyspark.sql.types import DoubleType, StringType, StructField, StructType, TimestampType

BRONZE_BASE = spark.conf.get("pipeline.bronze_path")
SILVER_BASE = spark.conf.get("pipeline.silver_path")

ehr_schema = StructType(
    [
        StructField("patient_id", StringType()),
        StructField("encounter_id", StringType()),
        StructField("event_time", TimestampType()),
        StructField("diagnosis_code", StringType()),
        StructField("doctor_id", StringType()),
        StructField("hospital_id", StringType()),
    ]
)

lab_schema = StructType(
    [
        StructField("patient_id", StringType()),
        StructField("encounter_id", StringType()),
        StructField("event_time", TimestampType()),
        StructField("test_code", StringType()),
        StructField("value", DoubleType()),
        StructField("unit", StringType()),
    ]
)

claim_schema = StructType(
    [
        StructField("claim_id", StringType()),
        StructField("patient_id", StringType()),
        StructField("payer_id", StringType()),
        StructField("service_date", TimestampType()),
        StructField("billed_amount", DoubleType()),
        StructField("claim_status", StringType()),
    ]
)


def cloudfiles(path: str, schema: StructType):
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.schemaEvolutionMode", "rescue")
        .schema(schema)
        .load(path)
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_source_file", F.input_file_name())
    )


@dlt.table(
    name="bronze_ehr",
    comment="Raw EHR records from hospital APIs, HL7/FHIR feeds, SQL Server, and Oracle exports.",
)
def bronze_ehr():
    return cloudfiles(f"{BRONZE_BASE}/ehr", ehr_schema)


@dlt.table(name="bronze_lab_results", comment="Raw lab result records.")
def bronze_lab_results():
    return cloudfiles(f"{BRONZE_BASE}/lab_result", lab_schema)


@dlt.table(name="bronze_claims", comment="Raw insurance claim records.")
def bronze_claims():
    return cloudfiles(f"{BRONZE_BASE}/insurance_claim", claim_schema)


@dlt.table(name="silver_ehr", comment="Validated and standardized EHR records.")
@dlt.expect_or_drop("valid_patient", "patient_id IS NOT NULL")
@dlt.expect_or_drop("valid_encounter", "encounter_id IS NOT NULL")
@dlt.expect_or_drop("valid_diagnosis", "diagnosis_code IS NOT NULL")
def silver_ehr():
    return (
        dlt.read_stream("bronze_ehr")
        .withColumn("diagnosis_code", F.upper(F.col("diagnosis_code")))
        .withWatermark("event_time", "2 hours")
        .dropDuplicates(["patient_id", "encounter_id", "event_time", "diagnosis_code"])
    )


@dlt.table(name="silver_lab_results", comment="Validated and standardized lab result records.")
@dlt.expect_or_drop("valid_patient", "patient_id IS NOT NULL")
@dlt.expect_or_drop("valid_test", "test_code IS NOT NULL")
@dlt.expect_or_drop("valid_result", "value IS NOT NULL")
def silver_lab_results():
    return (
        dlt.read_stream("bronze_lab_results")
        .withColumn("test_code", F.upper(F.col("test_code")))
        .withColumn("unit", F.upper(F.col("unit")))
        .withWatermark("event_time", "2 hours")
        .dropDuplicates(["patient_id", "encounter_id", "event_time", "test_code"])
    )


@dlt.table(name="silver_claims", comment="Validated insurance claim records.")
@dlt.expect_or_drop("valid_claim", "claim_id IS NOT NULL")
@dlt.expect_or_drop("valid_patient", "patient_id IS NOT NULL")
@dlt.expect_or_drop("non_negative_amount", "billed_amount >= 0")
def silver_claims():
    return (
        dlt.read_stream("bronze_claims")
        .withColumn("claim_status", F.upper(F.coalesce(F.col("claim_status"), F.lit("UNKNOWN"))))
        .dropDuplicates(["claim_id"])
    )


@dlt.table(name="gold_patient_outcomes", comment="Gold patient outcome indicators by encounter.")
def gold_patient_outcomes():
    ehr = dlt.read("silver_ehr")
    labs = dlt.read("silver_lab_results")
    return (
        ehr.join(labs, ["patient_id", "encounter_id"], "left")
        .groupBy("patient_id", "encounter_id", "doctor_id", "hospital_id")
        .agg(
            F.countDistinct("diagnosis_code").alias("diagnosis_count"),
            F.count("test_code").alias("lab_result_count"),
            F.max("event_time").alias("last_clinical_event_at"),
        )
    )


@dlt.table(name="gold_claims_analytics", comment="Gold claim measures for Snowflake claims marts.")
def gold_claims_analytics():
    return (
        dlt.read("silver_claims")
        .groupBy("payer_id", "claim_status")
        .agg(
            F.countDistinct("claim_id").alias("claim_count"),
            F.sum("billed_amount").alias("total_billed_amount"),
            F.avg("billed_amount").alias("avg_billed_amount"),
        )
    )
