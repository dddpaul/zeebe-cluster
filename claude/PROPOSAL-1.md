# Proposal: Fix Basic Authentication with Old ElasticsearchExporter

## Problem Summary

When using the **old ElasticsearchExporter** (`io.camunda.zeebe.exporter.ElasticsearchExporter`), Basic authentication in Operate UI fails because `DefaultCamundaAuthenticationProvider` is not initialized. With the **new CamundaExporter** (`io.camunda.exporter.CamundaExporter`), Basic authentication works correctly.

## Root Cause Analysis

The old `ElasticsearchExporter` **does not export identity-related records** to Elasticsearch. This is explicitly documented in the code:

**File**: `zeebe/exporters/elasticsearch-exporter/src/test/java/io/camunda/zeebe/exporter/TestSupport.java:120-127`

```java
// these are not yet supported
ValueType.AUTHORIZATION,
ValueType.USER,
ValueType.ROLE,
ValueType.TENANT,
ValueType.GROUP,
ValueType.MAPPING_RULE,
ValueType.IDENTITY_SETUP,
```

### What This Means

1. **User Initialization**: When the application starts with `camunda.security.initialization.users`, it creates users in the broker via commands
2. **Record Export**: The broker generates `USER_CREATED`, `ROLE_CREATED`, etc. records
3. **CamundaExporter**: Exports these records to Elasticsearch indices (`users-`, `roles-`, etc.)
4. **Old ElasticsearchExporter**: Does NOT export these records - they are excluded
5. **Authentication**: `DefaultCamundaAuthenticationProvider` queries Elasticsearch for user/role data
6. **Result**: With old exporter, the queries return empty results or fail, breaking authentication

### Authentication Chain

```
User Login → UsernamePasswordAuthenticationTokenConverter
           → RoleServices.getRolesForUser()
           → RoleSearchClient.query()
           → Elasticsearch (users-* / roles-* indices)
           → ??? (indices don't exist or are empty with old exporter)
```

## Why CamundaExporter Works

The `CamundaExporter` includes handlers for all identity record types:
- `UserCreatedUpdatedHandler` - exports user records
- `RoleCreateUpdateHandler` - exports role records
- `RoleMemberAddedHandler` / `RoleMemberRemovedHandler` - role membership
- `GroupCreateHandler` / `GroupMemberHandler` - group data
- `TenantCreateHandler` / `TenantMemberHandler` - tenant data
- `AuthorizationCreateHandler` - authorization records

These handlers ensure identity data is exported to Elasticsearch, making it available for authentication queries.

## Solution Options

### Option 1: Document the Incompatibility (Immediate)

The old `ElasticsearchExporter` is fundamentally incompatible with Basic authentication. Document this clearly:

> **Note**: Basic authentication requires the `CamundaExporter`. The legacy `ElasticsearchExporter` does not export identity data (users, roles, groups, tenants) and cannot be used with `camunda.security.authentication.method: basic`.

**Pros**:
- No code changes
- Clear expectation setting

**Cons**:
- Breaking change for users trying to use old exporter with Basic auth

### Option 2: Add Identity Export to Old Exporter (Major Effort)

Implement identity record export in the old `ElasticsearchExporter` similar to `CamundaExporter`.

**Pros**:
- Full backwards compatibility

**Cons**:
- Significant development effort
- Duplicates functionality already in CamundaExporter
- Old exporter is deprecated anyway

### Option 3: Fail Fast with Clear Error (Recommended)

Detect the incompatible configuration at startup and fail with a clear error message:

**File**: `authentication/src/main/java/io/camunda/authentication/config/WebSecurityConfig.java`

Add a check in `BasicConfiguration`:

```java
@PostConstruct
public void validateExporterCompatibility() {
    // Check if old ElasticsearchExporter is configured
    if (isLegacyExporterConfigured() && !isCamundaExporterConfigured()) {
        throw new BasicAuthenticationNotSupportedException(
            "Basic authentication requires CamundaExporter. The legacy ElasticsearchExporter " +
            "does not export identity data (users, roles, groups). Please migrate to " +
            "CamundaExporter or use a different authentication method.");
    }
}
```

**Pros**:
- Clear error message at startup
- Prevents confusing runtime failures
- Guides users to correct configuration

**Cons**:
- Requires detecting exporter configuration

## Recommendation

**Implement Option 3** (fail fast with clear error) combined with **Option 1** (documentation).

1. Add startup validation that detects old exporter + Basic auth configuration
2. Fail with a clear message explaining the incompatibility
3. Update documentation to clarify that CamundaExporter is required for Basic auth

## Key Code Locations

- **Old exporter exclusions**: `zeebe/exporters/elasticsearch-exporter/src/test/java/io/camunda/zeebe/exporter/TestSupport.java:120-127`
- **Old exporter config**: `zeebe/exporters/elasticsearch-exporter/src/main/java/io/camunda/zeebe/exporter/ElasticsearchExporterConfiguration.java`
- **CamundaExporter handlers**: `zeebe/exporters/camunda-exporter/src/main/java/io/camunda/exporter/handlers/`
- **Auth configuration**: `authentication/src/main/java/io/camunda/authentication/config/WebSecurityConfig.java`
- **Role services**: `service/src/main/java/io/camunda/service/RoleServices.java`

## Testing

An integration test should verify:
1. CamundaExporter + Basic auth → Works
2. Old ElasticsearchExporter + Basic auth → Fails fast with clear error
3. Old ElasticsearchExporter + OIDC/None auth → Works (no identity data needed from ES)

Test location: `qa/acceptance-tests/src/test/java/io/camunda/it/auth/`
