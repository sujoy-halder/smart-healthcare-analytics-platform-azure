{% macro apply_security_policies() %}
  alter table {{ ref('dim_patient') }}
    modify column patient_id set masking policy {{ target.database }}.analytics.mask_patient_identifier;
{% endmacro %}
