# Healthcare Domain Adapter

> Guardrails for healthcare and health tech projects. Auto-loaded when project-profile domain is `healthcare`.

## Compliance Requirements

- **HIPAA** (US): Protected Health Information (PHI) handling rules
  - PHI includes: names, dates, phone numbers, emails, SSN, medical record numbers, device identifiers, biometric data
  - Minimum Necessary Rule: only access/display PHI needed for the specific function
  - Business Associate Agreements (BAA) required for all third-party services handling PHI
- **GDPR** (EU): health data is "special category" — explicit consent required
- **HITECH Act**: breach notification within 60 days, penalty structure

## Data Handling Rules

- PHI encryption: at rest (AES-256) AND in transit (TLS 1.2+)
- Access logging: every PHI access must be logged (who, what, when, why)
- Data retention: define retention periods, implement automated deletion
- De-identification: Safe Harbor (remove 18 identifiers) or Expert Determination method
- Backups: encrypted, tested restoration, geographically restricted
- No PHI in logs, error messages, or analytics events

## Domain-Specific Guardrails

- **Architecture**: PHI data must be isolated in dedicated storage (not mixed with general application data)
- **Authentication**: MFA required for all PHI access
- **Session management**: automatic timeout (15 min for clinical, 30 min for admin)
- **Audit trail**: immutable log of all data access and modifications
- **API access**: OAuth 2.0 with scoped permissions per data type
- **Integration standards**: HL7 FHIR (R4+) for clinical data, ICD-10 for diagnosis, SNOMED CT for terminology, DICOM for imaging
- **EHR integration**: expect legacy systems, plan for adapter patterns
- **Clinical UX**: minimize clicks for frequent actions, confirmation dialogs for medication dosing, emergency break-glass access
- **Patient-facing**: health literacy considerations (plain language, WCAG AA minimum)

## Security Heightened Checks

- No PHI in client-side storage (sessionStorage, localStorage, cookies)
- No PHI in URL parameters
- API rate limiting per user (prevent bulk data extraction)
- Penetration testing: annual requirement for HIPAA compliance
- Vulnerability scanning: continuous for production systems
- Incident response plan: documented and tested

## Testing Requirements

- PHI boundary testing: verify PHI doesn't leak to logs, analytics, error reports
- Access control: verify role-based access (nurse vs doctor vs admin vs patient)
- Audit log completeness: every PHI access generates a log entry
- De-identification verification: ensure output contains no identifiable information
- Concurrent access: multiple providers accessing same patient record

## Scale Considerations

- Patient data growth: archival strategy for historical records
- Peak hours: clinical workflows concentrated in business hours
- Multi-facility: data isolation between facilities/organizations
- Reporting: OLAP/data warehouse for analytics (not production DB)
