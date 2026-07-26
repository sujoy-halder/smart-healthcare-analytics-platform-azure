# Databricks notebook source
snowflake_options = {
    "sfURL": dbutils.secrets.get("snowflake", "account_url"),
    "sfUser": dbutils.secrets.get("snowflake", "user"),
    "sfPassword": dbutils.secrets.get("snowflake", "password"),
    "sfDatabase": "HEALTHCARE_ANALYTICS",
    "sfSchema": "RAW",
    "sfWarehouse": "HEALTHCARE_LOADING_WH",
    "sfRole": "LOADER",
}

tables = {
    "gold_patient_outcomes": "PATIENT_OUTCOMES",
    "gold_claims_analytics": "CLAIMS_ANALYTICS",
}

for source_table, target_table in tables.items():
    (
        spark.table(f"healthcare_prod.silver.{source_table}")
        .write.format("snowflake")
        .options(**snowflake_options)
        .option("dbtable", target_table)
        .mode("overwrite")
        .save()
    )
