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

## Architecture Guardrails

- PHI data must be isolated in dedicated storage (not mixed with general application data)
- Authentication: MFA required for all PHI access
- Session management: automatic timeout (15 min for clinical, 30 min for admin)
- Audit trail: immutable log of all data access and modifications
- API access: OAuth 2.0 with scoped permissions per data type

## Integration Standards

- **HL7 FHIR**: preferred for clinical data exchange (R4 or later)
- **ICD-10**: diagnosis coding standard
- **SNOMED CT**: clinical terminology
- **DICOM**: medical imaging data
- EHR integration: expect legacy systems, plan for adapter patterns

## UI/UX Considerations

- Clinical workflows: minimize clicks for frequent actions (clinician time is critical)
- Error prevention: confirmation dialogs for medication dosing, patient identification
- Accessibility: WCAG AA minimum (many users have visual/motor impairments)
- Patient-facing: health literacy considerations (plain language, reading level)
- Emergency access: break-glass procedures for critical situations

## Testing Requirements

- PHI boundary testing: verify PHI doesn't leak to logs, analytics, error reports
- Access control: verify role-based access (nurse vs doctor vs admin vs patient)
- Audit log completeness: every PHI access generates a log entry
- De-identification verification: ensure output contains no identifiable information
- Concurrent access: multiple providers accessing same patient record

## Security Heightened Checks

- No PHI in client-side storage (sessionStorage, localStorage, cookies)
- No PHI in URL parameters
- API rate limiting per user (prevent bulk data extraction)
- Penetration testing: annual requirement for HIPAA compliance
- Vulnerability scanning: continuous for production systems
- Incident response plan: documented and tested

## Scale Considerations

- Patient data growth: archival strategy for historical records
- Peak hours: clinical workflows concentrated in business hours
- Multi-facility: data isolation between facilities/organizations
- Reporting: OLAP/data warehouse for analytics (not production DB)
