**1. SystemAdmin**

**1.1. Definition**

SystemAdmin defines the internal security identity of administrators
authorized to manage reference tables (Geography seeds, National ID
eligibility thresholds) and sign transition approvals for the global
system configuration. In alignment with VetoApp’s strict identity
separation rules, admins do not use standard client/voter profiles; they
operate through isolated key-based sessions under strict audit control.

**1.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key Role** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| admin_id | TINY UNSIGNED | No | — | PK | Unique auto-increment admin ID. |
| admin_uuid | BINARY(16) | No | — | UK | Immutable internal UUID for APIs and audit records. |
| username | VARCHAR(50) | No | — | UK | Unique administrative identifier. |
| password_hash | VARCHAR(255) | No | — | — | Secure password hash (Argon2id/Bcrypt). |
| public_key_pem | TEXT | No | — | — | RSA/Ed25519 public key used to verify manual cryptographic approvals (e.g., State 2 to 3 transitions). |
| is_active | TINYINT(1) | No | 1 | — | Boolean flag indicating whether this administrator’s access is active. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | — | Record creation DATETIME (UTC). |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | — | Last modification DATETIME (UTC). |

**1.3. Constraints and Business Rules**

- **Active Uniqueness**: If access needs to be revoked, is_active is
  updated to 0. Deleting administrative accounts directly is forbidden
  to maintain absolute integrity of foreign key constraints on audit
  ledgers and system state variables.

- **Security Configuration Integrity**: SystemAdmin records are stored
  in a dedicated administrative access domain. Password policies,
  multi-factor hardware keys, and token signing limits are controlled
  via application configuration and hardware modules.

**1.4. Relationships**

- SystemState: One-to-Many referencing SystemAdmin.admin_id (\to)
  SystemState.changed_by_admin_id (ON DELETE RESTRICT ON UPDATE
  RESTRICT).

- AdminActivityLog: One-to-Many referencing SystemAdmin.admin_id (\to)
  AdminActivityLog.admin_id (ON DELETE RESTRICT ON UPDATE RESTRICT).

**1.5. Indexes**

- PRIMARY KEY (admin_id)

- UNIQUE KEY uq_admin_uuid (admin_uuid)

- UNIQUE KEY uq_admin_username (username)

**2. AdminActivityLog**

**2.1. Definition**

AdminActivityLog is an immutable audit ledger recording every
administrative write, modification, or configuration state trigger. This
table guarantees absolute non-repudiation of core setup steps (seeding
geography, changing national eligibility boundaries, and initiating
transition stages).

**2.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key Role** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| log_id | BIGINT UNSIGNED | No | — | PK | Unique incremental audit log ID. |
| admin_id | TINY UNSIGNED | No | — | FK | Reference to the performing admin. |
| action_name | VARCHAR(100) | No | — | — | Logical category of action (e.g., ‘SEED_GEOGRAPHY’, ‘MUTATE_ELIGIBILITY’, ‘TRANSITION_SYSTEM_STATE’). |
| target_table | VARCHAR(64) | No | — | — | Database table name target of the mutation. |
| target_id | VARCHAR(128) | Yes | NULL | — | Primary key or identifier value of the target record. |
| payload_before | JSON | Yes | NULL | — | Database snapshot state before update. Must be NULL for insertions. |
| payload_after | JSON | Yes | NULL | — | Database snapshot state after update. |
| digital_signature | BINARY(64) | Yes | NULL | — | Cryptographic signature verifying administrative approval. |
| client_ip | VARCHAR(45) | No | — | — | IPv4 or IPv6 of the requesting client. |
| user_agent | VARCHAR(255) | Yes | NULL | — | User-Agent header of the administrative client. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | — | Timestamp of transaction commit (UTC). |

**2.3. Constraints and Business Rules**

- **Immutable Ledger**: Updates or deletes on AdminActivityLog are
  physically blocked at the engine tier via triggers. It is append-only.

- **Signature Enforcement**: Operational actions that mutate global
  settings (like altering system thresholds or modifying system state
  codes) must contain a valid cryptographic digital_signature matching
  the admin’s stored public key.

**2.4. Relationships**

- SystemAdmin: Many-to-One referencing admin_id (\to)
  SystemAdmin.admin_id (ON DELETE RESTRICT ON UPDATE RESTRICT).

**2.5. Indexes**

- PRIMARY KEY (log_id)

- INDEX idx_admin_log_admin (admin_id)

- INDEX idx_admin_log_action (action_name)

- INDEX idx_admin_log_target (target_table, target_id)

- INDEX idx_admin_log_created (created_at)

**\# 3. Country**

**\## 3.1. Definition**

Country root entity for the geographic hierarchy. All Province, County,
and Settlement records descend from it.

A Country is operationally valid only when is_active = 1.

**\## 3.2. Attributes**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| country_id | SMALLINT UNSIGNED | No | AUTO_INCREMENT | Surrogate primary key. |
| country_code | SMALLINT UNSIGNED | No | — | Unique official country code within system scope. |
| name_fa | VARCHAR(100) | No | — | Persian country name. |
| is_active | TINYINT(1) | No | 1 | Operational status. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC last-update DATETIME. |

**\## 3.3. Constraints and Rules**

- country_id is the primary key.

- country_code is NOT NULL and unique.

- name_fa is NOT NULL.

- Physical deletion is prohibited.

- Lifecycle is controlled through is_active.

- is_active = 1 means operationally valid; 0 means inactive.

- Any is_active change must be recorded in an audit table.

- All DATETIMEs are stored in UTC.

- created_at is assigned automatically on insert.

- updated_at is maintained automatically by the database.

**\## 3.4. Relationships**

- One-to-Many -\> Province (ON DELETE RESTRICT ON UPDATE RESTRICT)

**\## 3.5. Indexes**

- pk_countries (country_id)

- uq_country_code (country_code)

- idx_country_is_active (is_active)

**\# 4. Province**

**\## 4.1. Definition**

Province is the intermediate administrative layer between Country and
County.

A Province is operationally valid only when it and its parent Country
are active.

**\## 4.2. Attributes**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| province_id | SMALLINT UNSIGNED | No | AUTO_INCREMENT | Surrogate primary key. |
| country_id | SMALLINT UNSIGNED | No | — | FK to Country. |
| province_code | SMALLINT UNSIGNED | No | — | Unique official provincial code within system scope. |
| name_fa | VARCHAR(100) | No | — | Persian province name. |
| is_active | TINYINT(1) | No | 1 | Operational status. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC last-update DATETIME. |

**\## 4.3. Constraints and Rules**

\- province_id is the primary key.

\- country_id is NOT NULL and references countries.country_id.

\- province_code is NOT NULL and unique.

\- name_fa is NOT NULL.

\- Physical deletion is prohibited.

\- Lifecycle is controlled through is_active.

\- is_active = 1 means operationally valid; 0 means inactive.

\- A Province is valid only if both Province and parent Country are
active.

\- Any is_active change must be recorded in an audit table.

\- Inactivation propagates downward to all descendant County and
Settlement records.

\- Automatic propagation applies only to deactivation.

\- Reactivation must be explicit and controlled.

\- All DATETIMEs are stored in UTC.

\- created_at is assigned automatically on insert.

\- updated_at is maintained automatically by the database.

**\## 4.4. Relationships**

- Many-to-One -\> Country (ON DELETE RESTRICT ON UPDATE RESTRICT)

- One-to-Many -\> County (ON DELETE RESTRICT ON UPDATE RESTRICT)

**\## 4.5. Indexes**

- pk_provinces (province_id)

- idx_province_country_id (country_id)

- uq_province_code (province_code)

- idx_province_is_active (is_active)

**\# 5. County**

**\## 5.1. Definition**

County is the administrative unit below Province and above Settlement.

A County is operationally valid only when it, its parent Province, and
its parent Country are active.

**\## 5.2. Attributes**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| county_id | SMALLINT UNSIGNED | No | AUTO_INCREMENT | Surrogate primary key. |
| province_id | SMALLINT UNSIGNED | No | — | FK to Province. |
| county_code | SMALLINT UNSIGNED | No | — | Unique official county code within system scope. |
| name_fa | VARCHAR(100) | No | — | Persian county name. |
| is_active | TINYINT(1) | No | 1 | Operational status. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC last-update DATETIME. |

**\## 5.3. Constraints and Rules**

\- county_id is the primary key.

\- province_id is NOT NULL and references provinces.province_id.

\- county_code is NOT NULL and unique. - name_fa is NOT NULL.

\- Physical deletion is prohibited. - Lifecycle is controlled through
is_active.

\- is_active = 1 means operationally valid; 0 means inactive.

\- A County is valid only if County, parent Province, and parent Country
are active.

\- Any is_active change must be recorded in an audit table.

\- Inactivation propagates downward to all descendant Settlement
records.

\- Automatic propagation applies only to deactivation.

\- Reactivation must be explicit and controlled. - All DATETIMEs are
stored in UTC.

\- created_at is assigned automatically on insert.

\- updated_at is maintained automatically by the database.

**\## 5.4. Relationships**

- Many-to-One -\> Province (ON DELETE RESTRICT ON UPDATE RESTRICT)

- One-to-Many -\> Settlement (ON DELETE RESTRICT ON UPDATE RESTRICT)

**\## 5.5. Indexes**

- pk_counties (county_id)

- idx_county_province_id (province_id)

- uq_county_code (county_code)

- idx_county_is_active (is_active)

**\# 6. Settlement**

**\## 6.1. Definition**

Settlement is the lowest geographic level in the hierarchy.

A Settlement is operationally valid only when it, its parent County, its
parent Province, and its parent Country are active.

**\## 6.2. Attributes**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| settlement_id | SMALLINT UNSIGNED | No | AUTO_INCREMENT | Surrogate primary key. |
| county_id | SMALLINT UNSIGNED | No | — | FK to County. |
| name_fa | VARCHAR(100) | No | — | Persian settlement name. |
| settlement_code | SMALLINT UNSIGNED | No | — | Unique official settlement code within system scope. |
| is_active | TINYINT(1) | No | 1 | Operational status. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC last-update DATETIME. |

**\## 6.3. Constraints and Rules**

- settlement_id is the primary key.

- county_id is NOT NULL and references counties.county_id.

- name_fa is NOT NULL.

- settlement_code is NOT NULL and unique.

- Physical deletion is prohibited.

- Lifecycle is controlled through is_active.

- is_active = 1 means operationally valid; 0 means inactive.

- A Settlement is valid only if Settlement, parent County, parent
  Province, and parent Country are active.

- Any is_active change must be recorded in an audit table.

- All DATETIMEs are stored in UTC.

- created_at is assigned automatically on insert.

- updated_at is maintained automatically by the database.

**\## 6.4. Relationships**

- Many-to-One -\> County (ON DELETE RESTRICT ON UPDATE RESTRICT)

- Operational References -\> UserProfile(ON DELETE RESTRICT ON UPDATE
  RESTRICT)

- **\## 4.5. Indexes**

<!-- -->

- pk_settlements (settlement_id)

- idx_settlement_county_id (county_id)

- uq_settlement_code (settlement_code)

- idx_settlement_is_active (is_active)

**\## Cross-cutting policy**

> \- All four geographic entities use the same lifecycle model:

- is_active instead of physical deletion.

- is_active represents only the direct operational status of the entity
  itself.

- effective_operational_validity is a derived runtime value calculated
  by evaluating the entity and every ancestor in the geographic
  hierarchy.

- Effective operational validity is TRUE only when the entity itself and
  all of its ancestors have is_active = 1.

- Deactivation applies only to the targeted entity record. It must not
  physically update or propagate an inactive state to descendant rows.

- Descendants become effectively invalid through dynamic ancestor
  evaluation; their direct is_active values remain unchanged.

- Reactivation is never automatic and must be performed explicitly.

- Reactivating an ancestor does not reactivate a descendant whose own
  is_active value is 0.

- All is_active transitions must be audited.

- Foreign Key Action Policy: Every foreign key relationship MUST
  explicitly declare ON DELETE RESTRICT and ON UPDATE RESTRICT. ON
  DELETE CASCADE, ON DELETE SET NULL, ON UPDATE CASCADE, and ON UPDATE
  SET NULL are prohibited unless an entity-specific exception is
  explicitly documented

- .effective_operational_validity must not be stored as a persistent
  column.

- All DATETIMEs are stored in UTC and are database-managed.

- country_code, province_code, county_code, settlement_code, and name_fa
  remain the stable naming set across the hierarchy.

**\# 7. GeographicLevelLookup**

**\## 7.1. Definition**

GeographicLevelLookup is the authoritative registry of valid geographic
scope levels that may be assigned to a process target domain. It
standardizes the geographic abstraction used by the process engine and
ensures that all process scope definitions use a controlled,
machine-readable level vocabulary aligned with the normalized geographic
hierarchy of the system.

**\## 7.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| **geographic_level_code** | TINYINT UNSIGNED | No | — | PK | Canonical immutable machine-readable code for the geographic level. |
| **geographic_level_title** | VARCHAR(100) | No | — | — | Human-readable title for UI, reporting, and administration. |
| **hierarchy_rank** | TINYINT UNSIGNED | No | — | — | Numeric rank representing the level position within the geographic hierarchy. Lower rank indicates broader scope. |
| **lock_order** | TINYINT UNSIGNED | No | — | — | Deadlock-prevention acquisition order: Settlement=1, County=2, Province=3, Country=4. |
| **is_active** | TINYINT(1) | No | 1 | — | Indicates whether the geographic level is currently valid for use. |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | — | UTC creation DATETIME. |
| **updated_at** | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | — | UTC last modification DATETIME. |

**\## 7.3. Constraints and Business Rules**

\- Only the following four numeric geographic level codes are valid:
Country = 1, Province = 2 , County = 3 , Settlement = 4

\- geographic_level_code is numeric and is the machine-readable
foreign-key value. The human-readable name is stored in
geographic_level_title.

\- hierarchy_rank follows the broadest-to-narrowest hierarchy: Country =
1, Province = 2 , County = 3 , Settlement = 4

\- lock_order follows the deadlock-prevention acquisition order:
Settlement = 1 , County = 2 , Province = 3 , Country = 4

\- hierarchy_rank and lock_order are independent concepts and must not
be conflated.

\- Only rows with is_active = 1 may be used by new or updated process
records.

**\## 7.4. Relationships**

- Referenced by Process.target_geographic_level_code.

- May be referenced by validation logic that enforces exactly one
  matching target geographic foreign key on the base process entity.

**\## 7.5. Indexes**

- **PRIMARY KEY:** (geographic_level_code)

- **UNIQUE INDEX:** uq_geographic_level_lookup_hierarchy_rank on
  (hierarchy_rank)

- **INDEX:** idx_geographic_level_lookup_active on (is_active)

**\## 7.6. DDL Notes**

- MySQL 8.0 implementation must use TINYINT(1) for boolean fields.

- All temporal columns must use DATETIME, with UTC enforced at the
  application and transaction boundary.

- created_at and updated_at may use DEFAULT CURRENT_DATETIME, and
  updated_at may use ON UPDATE CURRENT_DATETIME, while remaining typed
  as DATETIME.

- geographic_level_code must use a case-sensitive collation if strict
  code comparison at database level is required.

- **seed data:**

| **geographic_level_code** | **geographic_level_title** | **hierarchy_rank** | **lock_order** | **is_active** |
|:--:|:--:|:--:|:--:|:--:|
| 1 | Country | 1 | 4 | 1 |
| 2 | Province | 2 | 3 | 1 |
| 3 | County | 3 | 2 | 1 |
| 4 | Settlement | 4 | 1 | 1 |

**\# 8: OTP**

**\## 8.1. Definition**

The OTP entity represents a short-lived One-Time Password token
generated for user authentication, registration, or password reset
actions. It enforces a strict purpose-bound relationship using either a
registration draft or an existing user account.

**\## 8.2. Attributes**

| **Column** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| otp_id | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Primary key of the OTP record. |
| mobile_hash | BINARY(32) | No | — | HMAC-SHA-256 hash of the normalized mobile number used for secure lookup and OTP binding context. |
| mobile_encrypted | VARBINARY(255) | No | — | AES-256-GCM encrypted normalized mobile number for controlled recovery or display. |
| purpose | VARCHAR(25) | No | — | Business purpose of the OTP. Foreign key referencing otp_purpose_lookup.purpose_code. |
| otp_nonce | BINARY(16) | No | — | Cryptographically secure random nonce generated per OTP issuance and used in code_hash derivation. |
| code_hash | BINARY(32) | No | — | Context-bound HMAC-SHA-256 digest of the OTP code using server-side secret and issuance context. Raw OTP must never be stored. |
| state | VARCHAR(15) | No | ‘Issued’ | Current lifecycle state. Foreign key referencing otp_state_lookup.state_code. |
| issued_at | DATETIME | No | — | UTC DATETIME of OTP issuance. |
| expires_at | DATETIME | No | — | UTC DATETIME after which the OTP becomes invalid. |
| verified_at | DATETIME | Yes | NULL | UTC DATETIME set only when the OTP is successfully verified. |
| failed_at | DATETIME | Yes | NULL | UTC DATETIME set only when the OTP transitions to Failed. |
| attempt_count | TINYINT UNSIGNED | No | 0 | Number of verification attempts made against this OTP. |
| max_attempt_count | TINYINT UNSIGNED | No | 3 | Maximum number of allowed verification attempts before failure. |
| delivery_channel | VARCHAR(15) | No | ‘telegram’ | Delivery channel used for OTP transmission. Allowed values: telegram, sms, voice. |
| registration_draft_id | BIGINT UNSIGNED | Yes | NULL | Optional foreign key to RegistrationDraft.registration_draft_id. Required when purpose = 'registration'. |
| user_id | BIGINT UNSIGNED | Yes | NULL | Optional foreign key to UserAccount.user_id. Required when purpose = 'password_reset'. |
| otp_throttle_window_id | BIGINT UNSIGNED | No | — | Foreign key to the throttle window that governed OTP issuance. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of record creation. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of last update. |

**\### 8.2.1. Lookup Table: otp_state_lookup**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| state_code | VARCHAR(15) | No | PK | Unique state code. |
| state_name | VARCHAR(100) | No | — | Human-readable state name. |
| is_active | TINYINT(1) | No | 1 | Indicates whether the lookup row is active. |
| display_order | INT | No | 0 | Presentation order. |

- Seed values: Issued, Verified, Expired, Failed

**\### 8.2.2. Lookup Table: otp_purpose_lookup**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| purpose_code | VARCHAR(25) | No | PK | Unique purpose code. |
| purpose_name | VARCHAR(100) | No | — | Human-readable purpose name. |
| is_active | TINYINT(1) | No | 1 | Indicates whether the lookup row is active. |
| display_order | INT | No | 0 | Presentation order. |

- Seed values: registration, password_reset

**\###** **8.3. Constraints and Rules**

- Mobile numbers must be normalized before hashing and encryption.

- Raw OTP values must never be stored.

- code_hash must be derived using HMAC-SHA-256 over:

  - otp_code

  - purpose

  - mobile_hash

  - otp_nonce

- purpose must reference otp_purpose_lookup(purpose_code).

- state must reference otp_state_lookup(state_code).

- delivery_channel must be limited to telegram, sms, and voice.

- expires_at must be greater than issued_at.

- attempt_count must never exceed max_attempt_count.

- verified_at must be NULL unless state = ‘Verified’.

- failed_at must be NULL unless state = ‘Failed’.

- Purpose-based integrity:

  - If purpose = 'registration', then registration_draft_id must be NOT
    NULL and user_id must be NULL.

  - If purpose = 'password_reset', then user_id must be NOT NULL and
    registration_draft_id must be NULL.

- Single Active OTP Constraint: For each mobile_hash + purpose, at most
  one active OTP may exist in Issued state with expires_at \> NOW. Any
  previous active OTP for the same mobile_hash + purpose must be
  invalidated (transitioned to Expired) before issuing a new one.

- Atomic Block Invalidation: Any transition of the corresponding
  OTPThrottleWindow for a mobile_hash to the Blocked state must
  atomically transition all associated active OTP records (where state =
  ‘Issued’) to state = ‘Failed’ and set failed_at = CURRENT_DATETIME.

- Referential Integrity Policy: All OTP foreign keys MUST enforce ON
  UPDATE RESTRICT and ON DELETE RESTRICT to preserve the audit trail and
  prevent orphaned OTP records. - purpose -\>
  otp_purpose_lookup(purpose_code) (RESTRICT/RESTRICT) - state -\>
  otp_state_lookup(state_code) (RESTRICT/RESTRICT) -
  registration_draft_id -\> registration_draft(registration_draft_id)
  (RESTRICT/RESTRICT) - user_id -\> user_account(user_id)
  (RESTRICT/RESTRICT)

**\### 8.3.1. State Transitions**

| **From State** | **To State** | **Trigger Condition** |
|:--:|:--:|:--:|
| Issued | Verified | Successful matching of code_hash and CURRENT_TIMESTAMP\<= expires_at. |
| Issued | Expired | CURRENT_TIMESTAMP\> expires_at OR invalidation due to new OTP issuance for the same mobile_hash + purpose. |
| Issued | Failed | attempt_count reaches max_attempt_count OR corresponding OTPThrottleWindow transitions to ‘Blocked’. |
| Verified | None | Terminal state. |
| Expired | None | Terminal state. |
| Failed | None | Terminal state. |

**\## 8.4. Relationships**

- RegistrationDraft: Many-to-One via registration_draft_id referencing
  RegistrationDraft.registration_draft_id .(nullable, required if
  purpose = ‘registration’).

- UserAccount: Many-to-One via user_id referencing UserAccount.user_id
  (nullable, required if purpose = ‘password_reset’).

- OTP State Lookup: Many-to-One via state referencing
  otp_state_lookup.state_code.

- OTP Purpose Lookup: Many-to-One via purpose referencing
  otp_purpose_lookup.purpose_code.
- OTPThrottleWindow: Many-to-One via otp_throttle_window_id referencing otp_throttle_windows.otp_throttle_window_id (ON DELETE RESTRICT, ON UPDATE RESTRICT).

**\## 8.5. Indexes**

- PRIMARY KEY (otp_id)

- INDEX idx_otp_lookup (mobile_hash, purpose, state)

- INDEX idx_otp_registration_draft (registration_draft_id) WHERE
  registration_draft_id IS NOT NULL

- INDEX idx_otp_throttle_window (otp_throttle_window_id)
- INDEX idx_otp_account (user_id) WHERE user_id IS NOT NULL

**\## 8.6. DDL Notes**

- Implement check constraints for delivery_channel to strictly enforce
  the allowed channel values.

**\# 9: OTPThrottleWindow**

**\## 9.1. Definition**

OTPThrottleWindow is a security enforcement entity operating
independently to track, monitor, and restrict rate requests and
validation failures associated with specific mobile numbers. It serves
as the primary barrier against brute-force attempts and SMS/Telegram
gateway resource exhaustion.

**\## 9.2. Attributes**

| **Column** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| otp_throttle_window_id | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Physical primary key. |
| mobile_hash | BINARY(32) | No | — | HMAC-SHA-256 hash of the E.164 normalized mobile number. |
| mobile_encrypted | VARBINARY(255) | No | — | AES-256-GCM encrypted mobile number for recovery/auditing. |
| window_started_at | DATETIME | No | — | Start DATETIME of the current tracking window (UTC). |
| window_ends_at | DATETIME | No | — | End DATETIME of the current tracking window (UTC). Set to 15 minutes after start. |
| send_count | TINYINT UNSIGNED | No | 0 | Number of OTP tokens dispatched within this window. |
| verify_failed_count | TINYINT UNSIGNED | No | 0 | Cumulative failed validation attempts across all tokens inside this window. |
| state | VARCHAR(15) | No | — | Window state. Foreign key referencing otp_throttle_window_state_lookup.state_code. |
| penalty_tier | TINYINT UNSIGNED | No | 0 | Tracking tier for progressive blocking penalty: 0 (none), 1 (15m), 2 (30m), 3 (60m). |
| last_sent_at | DATETIME | No | — | UTC DATETIME of the last sent OTP request to enforce inter-request intervals. |
| throttled_until | DATETIME | Yes | NULL | Cooldown expiration DATETIME for temporary throttling (UTC). |
| blocked_until | DATETIME | Yes | NULL | Penalty expiration DATETIME for severe blocking (UTC). |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | Physical record creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Last update DATETIME. |

**\### 9.2.1. Lookup Table: otp_throttle_window_state_lookup**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| state_code | VARCHAR(15) | No | PK | Unique state code. |
| state_name | VARCHAR(100) | No | — | Human-readable state name. |
| is_active | TINYINT(1) | No | 1 | Indicates whether the lookup row is active. |
| display_order | INT | No | 0 | Presentation order. |

- Seed values: Open, Throttled, Blocked, Expired

**\## 9.3. Constraints and Rules**

**\### 9.3.1. Policy Constraints & Values**

- Window Duration: Every new window defaults to exactly 15 minutes (900
  seconds).

- Window Duration: window_ends_at must be set to window_started_at +
  INTERVAL 15 MINUTE at the moment of record creation.

- Cumulative Failure Limit: Maximum of 5 cumulative verification
  failures allowed across all active tokens within a single window.
  Reaching 5 failures instantly transitions the state to Blocked.

- Max Dispatches: Maximum of 3 dispatches allowed within a single
  window. Exceeding 3 dispatches transitions the state to Throttled.

- Inter-Request Cooldown: A minimum of 60 seconds must elapse between
  two consecutive OTP requests for the same mobile_hash. Requests
  submitted before CURRENT_TIMESTAMP\>= last_sent_at + 60 seconds must
  be rejected.

- Progressive Penalty: When transitioning to Blocked, the penalty_tier
  increments by 1 (up to a maximum of 3). The blocked_until is
  calculated based on the new tier:

  - Tier 1: blocked_until = CURRENT_TIMESTAMP+ 15 minutes

  - Tier 2: blocked_until = CURRENT_TIMESTAMP+ 30 minutes

  - Tier 3: blocked_until = CURRENT_TIMESTAMP+ 60 minutes

- If a user triggers another block within a 24-hour cool-off period, the
  penalty_tier increments. If the cool-off period passes without a new
  block, the penalty_tier resets to 0.

**\### 9.3.2. State Dependency Controls**

- If state = 'Open' → throttled_until and blocked_until must be NULL.

- If state = 'Throttled' → throttled_until must be NOT NULL and
  blocked_until must be NULL.

- If state = 'Blocked' → blocked_until must be NOT NULL and
  throttled_until must be NULL.

- If state = 'Expired' → Window counters are no longer active, lock
  states are resolved.

**\### 9.3.3. State Transitions**

- Initial State: Open

- Terminal State: Expired

- Allowed Transitions:

  - Open → Throttled (when send_count \> 3 within the current window)

  - Open → Blocked (when verify_failed_count \>= 5 within the current
    window)

  - Open → Expired (automatically when current UTC time exceeds
    window_ends_at)

  - Throttled → Blocked (if a new validation failure occurs during a
    temporary throttle window)

  - Throttled → Expired (when current time exceeds throttled_until)

  - Blocked → Expired (when current time exceeds blocked_until)

**\## 9.4. Relationships**

- To optimize latency and facilitate complete horizontal shard
  isolation, this entity does not contain physical foreign key
  constraints referencing user profile tables. Verification mapping
  occurs logically in the application layer using the mobile_hash.

- OTP Throttle Window State Lookup: Many-to-One via state referencing
  otp_throttle_window_state_lookup.state_code (ON DELETE RESTRICT ON
  UPDATE RESTRICT).

**\## 9.5. Indexes**

- PRIMARY KEY (otp_throttle_window_id)

- UNIQUE KEY uq_throttle_active_lookup (mobile_hash, state,
  window_ends_at)

- INDEX idx_throttle_limits (throttled_until, blocked_until)

**\## 9.6. DDL Notes**

- The last_sent_at column must be updated atomically to prevent race
  conditions during concurrent user requests.

**\# 10: IntegrationInboxEntry**

**\## 10.1. Definition**

The IntegrationInboxEntry serves as an immutable, low-dependency audit
ledger for incoming external messaging events (e.g., Telegram Webhook
updates, SMS callback receipts).

**\## 10.2. Attributes**

| **Column** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| inbox_entry_id | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Primary key. |
| channel | VARCHAR(32) | No | — | Integration medium. Enum: ‘telegram’, ‘sms’, ‘system’. |
| external_message_id | VARCHAR(64) | Yes | NULL | The identifier sent by the external service provider. |
| correlation_hash | BINARY(32) | Yes | NULL | HMAC-SHA-256 hash containing a unique, non-reversible combination of transaction identifiers (e.g., combining the OTP’s nonce and lookup values). Used for matching incoming events without storing plaintext user identities. |
| payload | JSON | No | — | The raw, unparsed webhook or API callback data. |
| processed_status | VARCHAR(20) | No | ‘Pending’ | Processing status. Foreign key referencing integration_inbox_status_lookup.status_code. |
| received_at | DATETIME | No | — | UTC DATETIME when the incoming record was stored. |
| processed_at | DATETIME | Yes | NULL | UTC DATETIME when the record was processed and actioned. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of record creation. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of last update. |

**\## 10.2.1. Lookup Table: integration_inbox_status_lookup**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| status_code | VARCHAR(20) | No | PK | Unique status code. |
| status_name | VARCHAR(100) | No | — | Human-readable status name. |
| is_active | TINYINT(1) | No | 1 | Indicates whether the lookup row is active. |
| display_order | INT | No | 0 | Presentation order. |

- Seed values: Pending, Processed, Failed, Ignored

**\## 10.3. Constraints and Rules**

1.  Immutability: Once written, channel, external_message_id,
    correlation_hash, payload, and received_at must never be modified.
    Only processed_status and processed_at are eligible for single-state
    transitions.

2.  Correlation Matching: The application layer must compute the hash of
    incoming parameters matching the OTP setup to populate
    correlation_hash for resolution against the active OTP nonce
    context.

3.  No Direct User Reference: No physical foreign keys or direct
    plaintext references to UserAccount or UserProfile are allowed.

4.  Payload Encryption: To comply with privacy standards, if the payload
    JSON contains identifiable data, it must be encrypted at rest using
    the system’s master key, or the retention period must be strictly
    limited to 7 days before automated pruning

**\### 10.3.1. State Transitions**

| **From State** | **To State** | **Trigger Condition** |
|:--:|:--:|:--:|
| Pending | Processed | Webhook successfully matched, validated, and related action completed. |
| Pending | Failed | Processing failed due to validation errors or internal handler failure. |
| Pending | Ignored | Message judged irrelevant or duplicated. |

**\## 10.4. Relationships**

- Processed Status Lookup: Many-to-One via processed_status referencing
  integration_inbox_status_lookup.status_code.

**\## 10.5. Indexes**

- PRIMARY KEY (inbox_entry_id)

- INDEX idx_inbox_correlation (correlation_hash, processed_status)

- INDEX idx_inbox_received (received_at)

**\## 10.6. DDL Notes**

- JSON data validation must be performed at the application ingestion
  level.

**\# 11. NationalIdAreaEligibility**

**\## 11.1. Definition**

\`NationalIdAreaEligibility\` is a reference table used by the
application during the registration workflow to evaluate age eligibility
based on national ID segments.

Each row represents one first-three-digit national ID prefix. During
registration, the application extracts the first three digits and the
second three digits from the submitted national ID before storing only
the hashed and encrypted national ID values in \`RegistrationDraft\`.
The first segment is used to load the corresponding row from this table.
The second segment is evaluated in the application layer against two
allowed ranges defined in the row.

If the second segment falls within either allowed range, the applicant
may continue registration. Otherwise, the applicant is evaluated as not
satisfying the age eligibility requirement.

**\## 11.2. Attributes**

\- \`national_id_prefix_3\` — first three digits of the national ID;
stored as \`SMALLINT UNSIGNED\`; primary key.

\- \`first_range_from\` — lower bound of the first allowed range for the
second three-digit segment; stored as \`SMALLINT UNSIGNED\`.

\- \`first_range_to\` — upper bound of the first allowed range for the
second three-digit segment; stored as \`SMALLINT UNSIGNED\`.

\- \`second_range_from\` — lower bound of the second allowed range for
the second three-digit segment; stored as \`SMALLINT UNSIGNED\`.

\- \`second_range_to\` — upper bound of the second allowed range for the
second three-digit segment; stored as \`SMALLINT UNSIGNED\`.

\- \`created_at\` — record creation timestamp.

\- \`updated_at\` — record last update timestamp.

**\## 11.3. Constraints & Business Rules**

\- \`national_id_prefix_3\` is the primary key.

\- There is no separate surrogate identifier for this table.

\- All prefix and range boundary columns use \`SMALLINT UNSIGNED\`.

\- Each row defines two allowed ranges for the second three-digit
national ID segment.

\- The table has no foreign keys in the current model.

\- The table does not enforce registration eligibility at the database
level.

\- Registration eligibility is evaluated in the application layer before
national ID hash/encryption persistence.

\- \`RegistrationDraft\` stores only the hashed and encrypted national
ID values, not the extracted prefix or second segment.

\- If the second segment falls within either allowed range for the
matching prefix, registration may continue.

\- If no matching prefix row exists, or if the second segment falls
outside both ranges, the applicant is evaluated as age-ineligible.

\- Administrative seeding/update control may be introduced later if an
Admin/Operator entity is added.

**\## 11.4. Relationships**

None in the current model.

**\## 11.5. Indexes**

\- \`PRIMARY KEY (national_id_prefix_3)\`

**\# 12. RegistrationDraft**

**\## 12.1. Supporting Lookup**

**\### 12.1.1. RegistrationDraftStateLookup**

**\#### 12.1.1.1. Definition**

A static lookup table that defines the valid lifecycle states of a
registration draft. It establishes the terminal and active boundaries of
the onboarding process.

**\#### 12.1.1.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **state_code** | VARCHAR(15) | No |  | Unique state code (e.g., ‘Initiated’, ‘Completed’, ‘Expired’). Primary Key. |
| **state_name** | VARCHAR(100) | No |  | Human-readable name of the state. |
| **is_active** | TINYINT(1) | No | 1 | Determines if this state can currently be applied to new transitions. |
| **is_default** | TINYINT(1) | No | 0 | Indicates the default state when a draft is created. Exactly one row must be 1 (‘Initiated’). |
| **display_order** | INT UNSIGNED | No |  | Sequence order for UI/Reporting. |

**\#### 12.1.1.3. Constraints & Business Rules**

- **Single Default:** An application-level or database trigger
  constraint must enforce that exactly one record has is_default = 1.

**\#### 12.1.1.4. Relationships**

- **One-to-Many with RegistrationDraft:**

  - RegistrationDraftStateLookup.state_code is referenced by
    RegistrationDraft.state_code.

**\#### 12.1.1.5. Indexes**

- **Primary Key:** PRIMARY KEY (state_code)

- **Unique Constraints:** UNIQUE KEY uq_state_display_order
  (display_order)

**\### 12.1.2. RegistrationDraftStepLookup**

**\#### 12.1.2.1. Definition**

A static lookup table that represents the individual sequential steps
(wizard steps) within the active registration workflow.

**\#### 12.1.2.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **step_code** | VARCHAR(30) | No |  | Unique step identifier (e.g., ‘Mobile_Verification’, ‘National_ID_Verification’, ‘Geographic_Selection’, ‘Password_Selection’, ‘Biometric_Setup’, ‘Final_Review’). Primary Key. |
| **step_name** | VARCHAR(100) | No |  | Human-readable step name. |
| **is_active** | TINYINT(1) | No | 1 | Indicates if the step is currently enabled in the workflow. |
| **is_default** | TINYINT(1) | No | 0 | Indicates the default entry step for new drafts. Exactly one row must be 1 (‘Mobile_Verification’). |
| **display_order** | INT UNSIGNED | No |  | Operational flow sequence order. |

**\#### 12.1.2.3. Constraints & Business Rules**

- **Single Default:** An application-level or database trigger
  constraint must enforce that exactly one record has is_default = 1.

**\#### 12.1.2.4. Relationships**

- **One-to-Many with RegistrationDraft:**

  - RegistrationDraftStepLookup.step_code is referenced by
    RegistrationDraft.step_code.

**\#### 12.1.2.5. Indexes**

- **Primary Key:** PRIMARY KEY (step_code)

- **Unique Constraints:** UNIQUE KEY uq_step_display_order
  (display_order)

**\## 12.2. Main RegistrationDraft**

**\### 12.2.1. Definition**

Represents a temporary, stateful container for the user registration and
onboarding workflow. It enforces a strict 15-minute lifecycle and
ensures that sensitive data (Mobile/National ID) is protected via
encryption and cryptographic hashing. This entity serves as the “Source
of Truth” during the onboarding process before the atomic creation of a
permanent UserProfile and UserAccount.

**\### 12.2.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **registration_draft_id** | BIGINT UNSIGNED | No | *Identity* | Internal surrogate primary key. |
| **state_code** | VARCHAR(15) | No |  | Reference to RegistrationDraftStateLookup. |
| **step_code** | VARCHAR(30) | No |  | Reference to RegistrationDraftStepLookup. |
| **idempotency_key** | VARCHAR(80) | No |  | Unique token to prevent duplicate request processing. |
| **mobile_hash** | BINARY(32) | No |  | **HMAC-SHA-256** hash of the normalized E.164 mobile number. |
| **mobile_encrypted** | VARBINARY(255) | Yes | NULL | **AES-256-GCM** encrypted E.164 mobile number. |
| **national_id_hash** | BINARY(32) | Yes | NULL | **HMAC-SHA-256** hash of the National ID. Required from National_ID_Verification step. |
| **national_id_encrypted** | VARBINARY(255) | Yes | NULL | **AES-256-GCM** encrypted National ID. |
| **key_version** | SMALLINT UNSIGNED | Yes | NULL | Envelope encryption key version. |
| **settlement_id** | SMALLINT UNSIGNED | Yes | NULL | Geographic endpoint anchor. Required from Geographic_Selection step onwards. |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | Record creation DATETIME(UTC). |
| **updated_at** | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Last modification DATETIME (UTC). Auto-updates on edit in MySQL. |
| **expires_at** | DATETIME | No |  | Expiration DATETIME (created_at + 15 minutes). |
| **completed_at** | DATETIME | Yes | NULL | DATETIME when the draft was successfully completed. |
| **active_mobile_hash** | BINARY(32) | Yes | *STORED GENERATED* | Stored Generated Column: IF(state_code IN ('Initiated'), mobile_hash, NULL). Enforces one active draft per mobile. |
| **active_national_id_hash** | BINARY(32) | Yes | *STORED GENERATED* | Stored Generated Column: IF(state_code IN ('Initiated') AND step_code \<\> ('Mobile_Verification'), national_id_hash, NULL). Enforces one active draft per National ID. |

**\### 12.2.3. Constraints & Business Rules**

1.  **Data Normalization & Encryption Standards:**

    - **Mobile Normalization:** Prior to hashing and encryption, the
      mobile number must be normalized to the E.164 format (e.g.,
      +989121234567).

    - **Cryptographic Hashing:** mobile_hash and national_id_hash use
      HMAC-SHA-256 to verify unique identity drafts without decrypting
      data.

    - **Data Wipe Rule:** Once the transaction shifts state_code to
      Completed, all encrypted data (mobile_encrypted,
      national_id_encrypted) and key_version must be set to NULL
      (cryptographic erasure).

2.  **Lifecycle & Expiry Rules:**

    - **Lifespan:** A draft is valid for exactly 15 minutes.
      Database-level constraints must enforce:

- CHECK (expires_at = (created_at + INTERVAL 15 MINUTE))

  - **Terminal State Integrity:** Once a draft transitions to Completed
    or Expired, it is immutable.

- CHECK ( (state_code = 'Completed' AND completed_at IS NOT NULL) OR
  (state_code != 'Completed' AND completed_at IS NULL) )

3.  **Step-Based Validation Rules (Not-Null Transitions):**

    - **National ID Mandatoriness:** From the step
      National_ID_Verification and all subsequent steps, the national
      identity cryptographic data must not be empty.

- CHECK ( (step_code IN ('Mobile_Verification') OR (national_id_hash IS
  NOT NULL AND national_id_encrypted IS NOT NULL AND key_version IS NOT
  NULL)) )

  - **Geographic Mandatoriness:** From the step Geographic_Selection and
    all subsequent steps, the geographic root identifier must not be
    empty.

- CHECK ( (step_code IN ('Mobile_Verification',
  'National_ID_Verification') OR settlement_id IS NOT NULL) )

4.  **Geographic Integrity:**

    - The settlement_id acts as the root geographic anchor. The Country,
      Province, and County are strictly derived and validated from this
      point.

> **5. Identity and Cooldown Gatekeeping Rule:**
>
> To minimize resources and prevent system abuse, the registration API
> must actively block progression during the following steps without
> persisting a rejected database state (the draft remains in its current
> state until natural expiration):
>
> o **Mobile Verification Step:**
>
> After normalizing the mobile number and computing mobile_hash, the
> system must verify that no active UserProfile exists with the same
> mobile_hash. If an active profile exists, the current interactive
> request must stop immediately and return the appropriate business
> response. The draft remains in its current state and may naturally
> expire according to its lifecycle rules.
>
> o **National ID Verification Step:**
>
> After normalizing the National ID and computing national_id_hash, and
> before invoking expensive external verification services, the system
> must verify: i. no active UserProfile exists with the same
> national_id_hash; and ii. no NationalIdCooldownLedger record exists
> for which CURRENT_TIMESTAMP \< cooldown_until. If either condition
> fails, the current interactive request must stop immediately and
> return the appropriate business response. No new lifecycle state is
> created. The draft remains in its current state and may naturally
> expire. c. Final Atomic Completion Check: The final transaction that
> creates UserProfile and UserAccount must repeat the mobile uniqueness,
> National ID uniqueness, and National ID cooldown checks to prevent
> race conditions.

**\### 12.2.4. Relationships**

- **Many-to-One with RegistrationDraftStateLookup:**

  - RegistrationDraft.state_code references
    RegistrationDraftStateLookup.state_code

  - *On Update: Restrict \| On Delete: Restrict*

- **Many-to-One with RegistrationDraftStepLookup:**

  - RegistrationDraft.step_code references
    RegistrationDraftStepLookup.step_code

  - *On Update: Restrict \| On Delete: Restrict*

- **Many-to-One with Settlement:**

  - RegistrationDraft.settlement_id references Settlement.settlement_id

  - *On Update: Restrict \| On Delete: Restrict*

**\### 12.2.5. Indexes**

- **Primary Key:**

  - PRIMARY KEY (registration_draft_id)

- **Unique Constraints:**

  - UNIQUE KEY uq_registration_drafts_idempotency (idempotency_key)

  - UNIQUE KEY uq_active_draft_per_mobile (active_mobile_hash) *(MySQL
    8.0 ignores NULL values, permitting multiple completed/expired
    drafts but restricting active duplicates).*

  - UNIQUE KEY uq_active_draft_per_national_id (active_national_id_hash)
    *(Enforces a single active registration draft per National ID
    starting from the National_ID_Verification step).*

- **Performance Indexes:**

  - INDEX idx_registration_drafts_expires (expires_at, state_code)

  - INDEX idx_registration_drafts_mobile_hash (mobile_hash)

**\# 13. UserProfile**

**\## 13.1. Definition**

UserProfile is the authoritative identity profile of a registered user
in VetoApp. It stores the user’s core identity anchors, protected mobile
and national-ID identifiers, active status, and enforced geographic
scope.

The entity uses a shared primary key with UserAccount to guarantee a
strict one-to-one identity/account structure. The user’s final geography
is anchored at the Settlement level, while parent geographic references
are stored for consistency checks, filtering, quorum calculation, and
geo-scoped process execution.

**\## 13.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **user_id** | BIGINT UNSIGNED | No | — | Shared Primary Key. Also references the corresponding UserAccount.user_id in a strict 1:1 identity/account model. |
| **mobile_hash** | BINARY(32) | Yes | NULL | HMAC-SHA-256 unique identifier hash of the normalized E.164 mobile number. Nullified upon voluntary account closure to release the unique constraint. |
| **mobile_encrypted** | VARBINARY(255) | Yes | NULL | AES-256-GCM encrypted mobile phone number (E.164 format) for system communication and account recovery. Protected via Envelope Encryption. Nullified upon voluntary account closure. |
| **national_id_hash** | BINARY(32) | Yes | NULL | HMAC-SHA-256 unique identifier hash of the user’s national identity card number to prevent duplicate active profiles. Nullified upon voluntary account closure. |
| **national_id_encrypted** | VARBINARY(255) | Yes | NULL | AES-256-GCM encrypted National ID card number for recovery or administrative verification. Protected via Envelope Encryption. Nullified upon voluntary account closure. |
| **settlement_id** | SMALLINT UNSIGNED | No | — | Final and authoritative geographic leaf node assigned to the user. References Settlement.settlement_id. |
| **county_id** | SMALLINT UNSIGNED | No | — | Materialized parent county identifier derived from the selected settlement_id. Stored for query efficiency and must remain hierarchy-consistent. |
| **province_id** | SMALLINT UNSIGNED | No | — | Materialized parent province identifier derived from the selected settlement_id. Stored for query efficiency and must remain hierarchy-consistent. |
| **country_id** | SMALLINT UNSIGNED | No | — | Materialized parent country identifier derived from the selected settlement_id. Stored for query efficiency and must remain hierarchy-consistent. |
| **is_active** | TINYINT(1) | No | 1 | Global active status of the user identity. If set to 0, all active authentication sessions associated with the user must be invalidated atomically by application/service transaction orchestration. |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME indicating profile creation time. |
| **geo_updated_at** | DATETIME | No | CURRENT_TIMESTAMP | geo_updated_at must be updated only when a geographic reassignment is successfully accepted. It must not use ON UPDATE CURRENT_TIMESTAMP. |
| **initial_geo_selected_at** | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME indicating the first successful geographic selection during registration completion. On first creation, it must equal created_at and geo_updated_at. |

**\## 13.3. Constraints & Business Rules**

1.  **Shared Primary Key Model:**

user_id is the primary key of UserProfile and participates in a strict
shared-primary-key one-to-one relationship with UserAccount.

A profile cannot exist without its corresponding account identity chain,
and a second profile for the same user is structurally impossible.

2.  **Anonymous External Interaction Boundary:**

Direct usage of user_id in those domains is prohibited by architecture.

3.  **Identity Uniqueness Enforcements (Sybil Protection):**

    - mobile_hash must be globally unique across all profiles when
      present (not NULL). Multiple active accounts cannot share the same
      mobile identifier.

    - national_id_hash must be globally unique across all profiles when
      present (not NULL). Each physical person is restricted to a single
      active registered profile.

4.  **Active Profile Identity Integrity (CHECK Constraint):**

To guarantee that active users always have verified identity records,
the database must enforce the following rule using a MySQL 8.0 CHECK
constraint:

CONSTRAINT chk_user_profile_active_identity CHECK (is_active = 0 OR
(mobile_hash IS NOT NULL AND mobile_encrypted IS NOT NULL AND
national_id_hash IS NOT NULL AND national_id_encrypted IS NOT NULL))

5.  **Voluntary Closure Anonymization & Cooldown Flow:**

> When a user voluntarily closes their account, the application must
> execute one atomic transaction that:
>
> a\. Reads the current national_id_hash from UserProfile.
>
> b\. Inserts or updates NationalIdCooldownLedger using that
> national_id_hash and applies the progressive cooldown rule.
>
> c\. Sets UserProfile.is_active = 0.
>
> d\. Sets UserAccount.account_status = 'Closed'.
>
> e\. Nullifies the identity fields in UserProfile:
>
> mobile_hash = NULL,
>
> mobile_encrypted = NULL,
>
> national_id_hash = NULL,
>
> national_id_encrypted = NULL.
>
> f\. Invalidates all active AuthSession records belonging to the user.
>
> The transaction must commit only if all steps succeed. If any step
> fails, the entire transaction must roll back.

6.  **Cryptographic Protection of Identity Fields:**

    - Plain-text mobile numbers and national IDs must never be stored in
      database fields. They must be encrypted (mobile_encrypted,
      national_id_encrypted) utilizing an approved cryptographic key
      management service (KMS) or dynamic envelope encryption using
      AES-256-GCM.

    - Identity hashes (mobile_hash, national_id_hash) must use a strong,
      peppered HMAC-SHA-256 configuration to prevent dictionary attacks
      on stored hashes.

7.  **Geographic Leaf Authority Rule:**

settlement_id is the authoritative user geography anchor.

The user’s final location is always defined at the Settlement level, not
at province, county, or country level alone.

8.  **Strict Geographic Hierarchy Enforcement:**

country_id, province_id, and county_id are required denormalized parent
references derived from settlement_id.

They must always match the actual geographic hierarchy of the referenced
settlement.

Any insert or update that causes hierarchy mismatch must be rejected.

> **9.Non-Nullable Geography Rule:**

settlement_id, county_id, province_id, and country_id are all mandatory
and must never be NULL.

The system does not permit partially assigned geographic identity for
registered users.

> **10.Dynamic Geographic Cooldown Rule:**

User-initiated geographic reassignment after initial registration is
restricted by the active GeoCooldownPolicy. The cooldown duration must
not be hard-coded in UserProfile. Before accepting a geographic
reassignment, the system must evaluate the applicable policy using the
current geographic state and the accepted change history in
UserGeoChangeLog. If the reassignment is accepted, the system must
update the geographic fields in UserProfile, update geo_updated_at, and
insert an immutable UserGeoChangeLog record in the same atomic
transaction.

> **11.Administrative/System Bypass Rule:**
>
> The active geographic cooldown policy may be bypassed only by
> explicitly authorized administrative or trusted system operations. A
> bypass must never be available to ordinary user-originated requests.
> Every bypass must be recorded in UserGeoChangeLog with: -
> change_source = 'Admin' or 'System'; and - bypass_reason IS NOT NULL.
>
> **12.Initial Geographic DATETIME Rule:**

On first successful user registration completion,
initial_geo_selected_at, geo_updated_at, and created_at must all be set
consistently within the same atomic completion transaction.

> **13.Session Invalidation Consistency Rule:**

Any transition of is_active from 1 to 0 must trigger atomic invalidation
of all active AuthSession records belonging to the same user.

This must be coordinated transactionally at the service/application
layer, or through a controlled database-backed consistency mechanism, so
that no valid session survives deactivation.

> **14..Geographic Change Logging Rule:**

UserProfile stores the current authoritative geographic assignment only.
Every accepted geographic reassignment must be recorded as an immutable
row in UserGeoChangeLog. The UserProfile update and the UserGeoChangeLog
insertion must occur in the same atomic transaction.

> **15.UTC DATETIME Rule:**

All DATETIME fields in this entity must be stored in UTC using MySQL 8.0
DATETIME.

**\## 13.4. Relationships**

- **One-to-One with UserAccount:**

  - UserProfile.user_id ↔ UserAccount.user_id

  - Implemented using a **shared primary key** pattern.

- **Many-to-One with Settlement:**

  - UserProfile.settlement_id → Settlement.settlement_id

- **Many-to-One with County:**

  - UserProfile.county_id → County.county_id

- **Many-to-One with Province:**

  - UserProfile.province_id → Province.province_id

- **Many-to-One with Country:**

  - UserProfile.country_id → Country.country_id

- **One-to-Many logical relation with AuthSession:**

  - A single user profile may own multiple authentication sessions
    through the shared user identity.

  - On deactivation, all such sessions must be invalidated atomically.

**\## 13.5. Indexes**

- **Primary Key:**

  - PRIMARY KEY (user_id)

- **Unique Constraints:**

  - UNIQUE KEY uq_user_profile_mobile_hash (mobile_hash)

  - UNIQUE KEY uq_user_profile_national_id_hash (national_id_hash)

- **Foreign Key / Join Performance Indexes:**

  - INDEX idx_user_profile_settlement_id (settlement_id)

  - INDEX idx_user_profile_county_id (county_id)

  - INDEX idx_user_profile_province_id (province_id)

  - INDEX idx_user_profile_country_id (country_id)

- **Composite Geography Query Indexes:**

  - INDEX idx_user_profile_geo_chain (country_id, province_id,
    county_id, settlement_id)

  - INDEX idx_user_profile_settlement_active (settlement_id, is_active)

**\## 13.6. Final Architectural Notes**

1.  **Duplicate and Abuse Prevention:**

The combinations of unique national_id_hash and mobile_hash secure the
platform against Sybil attacks and ensure that each physical citizen can
only participate with one logical account.

2.  **Redundant Geography Storage:**

Although derivable from settlement_id, storing county_id, province_id,
and country_id directly improves filtering, aggregation, quorum
calculations, and geo-scoped process execution performance.

3.  **Atomic Setup:**

The creation of UserProfile and its hashes/encrypted fields happens in a
single MySQL transaction along with the creation of the UserAccount
using their shared primary key.

**\# 14.UserGeoChangeLog**

**\## 14.1.Definition**

An immutable audit ledger that records every accepted geographic
reassignment of a registered user. It supports dynamic geographic
cooldown enforcement, administrative review, abuse detection, and
historical traceability.

**\## 14.2.Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| geo_change_log_id | BIGINT UNSIGNED | No | Identity | Internal surrogate primary key. |
| user_id | BIGINT UNSIGNED | No | — | References the user whose geographic assignment was changed. FK to UserProfile. |
| old_settlement_id | SMALLINT UNSIGNED | No | — | Previous settlement before the accepted change. |
| new_settlement_id | SMALLINT UNSIGNED | No | — | New settlement after the accepted change. |
| old_county_id | SMALLINT UNSIGNED | No | — | Previous derived county identifier. |
| new_county_id | SMALLINT UNSIGNED | No | — | New derived county identifier. |
| old_province_id | SMALLINT UNSIGNED | No | — | Previous derived province identifier. |
| new_province_id | SMALLINT UNSIGNED | No | — | New derived province identifier. |
| old_country_id | SMALLINT UNSIGNED | No | — | Previous derived country identifier. |
| new_country_id | SMALLINT UNSIGNED | No | — | New derived country identifier. |
| change_source | VARCHAR(20) | No | — | Source of the change: User, Admin, System. |
| policy_id | SMALLINT UNSIGNED | Yes | NULL | Optional reference to the dynamic geographic cooldown policy applied. |
| bypass_reason | VARCHAR(255) | Yes | NULL | Required only when cooldown was bypassed by authorized admin/system flow. |
| changed_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME when the geographic change was accepted. |

**\## 14.3.Constraints & Business Rules**

1.  **Immutable Ledger Rule:** Records in UserGeoChangeLog must be
    append-only. Updates and deletes are prohibited.

2.  **No-Op Change Rejection:** The system must reject geographic
    changes where old_settlement_id = new_settlement_id.

3.  **Bypass Governance Rule:** If change_source is Admin or System and
    the normal cooldown is bypassed, a non-null bypass_reason must be
    provided.

4.  **Atomic Update Rule:** Updating UserProfile geographic fields and
    inserting the corresponding UserGeoChangeLog row must occur within
    the same database transaction.

5.  **UTC DATETIME Rule:** All DATETIME fields must store values in UTC.

**\## 14.4.Relationships**

- Many-to-One with UserProfile:

  - UserGeoChangeLog.user_id references UserProfile.user_id

  - ON UPDATE RESTRICT ON DELETE RESTRICT

- Many-to-One with Settlement:

  - old_settlement_id, new_settlement_id reference
    Settlement.settlement_id

  - ON UPDATE RESTRICT ON DELETE RESTRICT

**\## 14.5.Indexes**

- PRIMARY KEY (geo_change_log_id)

- INDEX idx_user_geo_change_user_changed (user_id, changed_at)

- INDEX idx_user_geo_change_new_geo (new_country_id, new_province_id,
  new_county_id, new_settlement_id)

**\# 15.GeoCooldownPolicy**

**\## 15.1.Definition**

GeoCooldownPolicy defines the versioned enforcement rules that control
how frequently a user may change their geographic assignment in VetoApp.
It is the authoritative policy entity for geographic reassignment
cooldowns and replaces hardcoded or application-only rule logic.

*\#* **15.2.Attributes**

| **Attribute** | **Type** | **Null** | **Key** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| policy_id | SMALLINT UNSIGNED | No | PK | Auto-increment | Unique identifier of the policy row. |
| policy_code | VARCHAR(50) | No | UQ | — | Stable machine-readable policy code. |
| policy_name | VARCHAR(150) | No | — | — | Human-readable policy name. |
| description | VARCHAR(500) | Yes | — | NULL | Optional explanatory text. |
| max_changes_allowed | TINYINT UNSIGNED | No | — | — | Maximum allowed geographic changes within the evaluation window. |
| window_days | SMALLINT UNSIGNED | No | — | — | Rolling or fixed window size in days. |
| cooldown_days | SMALLINT UNSIGNED | No | — | — | Enforced cooldown duration in days after threshold violation. |
| is_active | TINYINT(1) | No | — | 1 | Indicates whether this policy version is currently active. |
| effective_from | DATETIME | No | — | — | UTC timestamp from which the policy becomes effective. |
| effective_to | DATETIME | Yes | — | NULL | UTC timestamp at which the policy stops being effective. |
| created_at | DATETIME | No | — | CURRENT_TIMESTAMP | Row creation timestamp in UTC. |
| updated_at | DATETIME | No | — | CURRENT_TIMESTAMP | Last update timestamp in UTC. |

*\##* **15.3.Constraints & Business Rules**

- policy_code must be unique.

- max_changes_allowed must be greater than zero.

- window_days must be greater than zero.

- cooldown_days must be greater than zero.

- effective_to must be greater than effective_from when present.

- Only one active policy version should be used for evaluation at any
  given time.

- The policy must be evaluated synchronously with UserGeoChangeLog
  before accepting a geographic reassignment.

- Policy rows are immutable in meaning after activation; if business
  rules change, a new version should be inserted instead of overwriting
  the old one.

- Deletion must be restricted if any historical log or enforcement
  reference exists.

*\##* **15.4.Relationships**

- One GeoCooldownPolicy may be referenced by many UserGeoChangeLog rows.

- Each UserGeoChangeLog row may optionally store the policy used during
  evaluation.

- GeoCooldownPolicy is read by the enforcement path and must not be
  modified by transactional acceptance logic.

*\#* **15.5.Indexes**

- PRIMARY KEY (policy_id)

- UNIQUE KEY uq_geo_cooldown_policy_code (policy_code)

- KEY idx_geo_cooldown_policy_active (is_active, effective_from,
  effective_to)

**\# 16.NationalIdCooldownLedger**

**\## 16.1.Definition**

NationalIdCooldownLedger is a privacy-preserving immutable ledger that
tracks progressive re-registration penalties for voluntarily closed
accounts using only the cryptographic hash of the National ID. The
applied cooldown duration is resolved from AccountClosurePenaltyPolicy
at enforcement time to prevent hardcoded penalty logic and support
policy versioning.

**\## 16.2.Attributes**

| **Attribute** | **Type** | **Null** | **Key** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| national_id_hash | BINARY(32) | No | PK | — | HMAC-SHA-256 hash of the normalized National ID. |
| closure_count | TINYINT UNSIGNED | No | — | 1 | Number of voluntary closures recorded for this National ID. |
| policy_id | SMALLINT UNSIGNED | No | FK | — | References the applied AccountClosurePenaltyPolicy version used for this ledger row. |
| cooldown_days | SMALLINT UNSIGNED | No | — | — | Cooldown duration resolved from the referenced policy. |
| cooldown_until | DATETIME | No | — | — | UTC datetime until which re-registration is blocked. |
| last_closed_at | DATETIME | No | — | CURRENT_TIMESTAMP | UTC datetime of the latest voluntary account closure. |
| created_at | DATETIME | No | — | CURRENT_TIMESTAMP | UTC datetime when this ledger row was first created. |
| updated_at | DATETIME | No | — | CURRENT_TIMESTAMP | UTC datetime of the latest ledger update. |

**\## 16.3.Constraints & Business Rules**

- Plain-text National ID must never be stored in this table.

- national_id_hash must be unique and immutable.

- policy_id must reference an active AccountClosurePenaltyPolicy row at
  the time of enforcement.

- closure_count must increment atomically on each voluntary closure.

- cooldown_days must be derived from the referenced policy, not
  hardcoded in application logic.

- cooldown_until must be calculated as last_closed_at + INTERVAL
  cooldown_days DAY.

- Re-registration is allowed only when CURRENT_TIMESTAMP \>=
  cooldown_until.

- The closure transaction must lock the relevant ledger row before
  updating it.

- If no row exists, insert-or-update must be atomic to prevent duplicate
  concurrent processing.

- Updating this ledger must occur in the same transaction as closing the
  account/profile.

- All DATETIME fields must be stored in UTC.

**\## 16.4.Relationships**

- Each NationalIdCooldownLedger row must reference exactly one
  AccountClosurePenaltyPolicy.

- One AccountClosurePenaltyPolicy may govern many
  NationalIdCooldownLedger rows.

- The policy relation preserves auditability of which penalty rule was
  applied at closure time.

- The ledger may also be evaluated by registration gatekeeping logic
  before allowing re-entry.

**\## 16.5.Indexes**

- PRIMARY KEY (national_id_hash)

- KEY idx_national_id_cooldown_until (cooldown_until)

- KEY idx_national_id_policy_id (policy_id)

**\# 17.AccountClosurePenaltyPolicy**

**\## 17.1.Definition**

AccountClosurePenaltyPolicy defines the versioned cooldown and penalty
rules applied when a user closes an account and later attempts to
re-register or re-enter an identity-linked workflow. It is the
authoritative policy entity for progressive penalties such as 30, 60,
90, and 180 days.

**\## 17.2.Attributes**

| **Attribute** | **Type** | **Null** | **Key** | **Default** | **Description** |
|----|----|----|----|----|----|
| policy_id | SMALLINT UNSIGNED | No | PK | Auto-increment | Unique identifier of the policy row. |
| policy_family_code | VARCHAR(50) | No | — | — | Logical policy family used to group versioned stages. |
| policy_code | VARCHAR(50) | No | UQ | — | Stable machine-readable policy code. |
| policy_name | VARCHAR(150) | No | — | — | Human-readable policy name. |
| description | VARCHAR(500) | Yes | — | NULL | Optional policy description. |
| penalty_stage | TINYINT UNSIGNED | No | — | — | Progressive stage number for the penalty scheme. |
| penalty_days | SMALLINT UNSIGNED | No | — | — | Cooldown duration in days for this stage. |
| trigger_scope | VARCHAR(50) | No | — | — | Scope that activates the penalty, fixed to account closure. |
| is_active | TINYINT(1) | No | — | 1 | Indicates whether this policy version is currently active. |
| effective_from | DATETIME | No | — | — | UTC timestamp from which the policy becomes effective. |
| effective_to | DATETIME | Yes | — | NULL | UTC timestamp at which the policy stops being effective. |
| created_at | DATETIME | No | — | CURRENT_TIMESTAMP | Row creation timestamp in UTC. |
| updated_at | DATETIME | No | — | CURRENT_TIMESTAMP | Last update timestamp in UTC. |

**\## 17.3.Constraints & Business Rules**

- policy_code must be unique.

- penalty_stage must be unique within the policy family (policy_family_code, penalty_stage).

- penalty_days must be a positive value.

- trigger_scope must be fixed to the account-closure use case.

- effective_to must be greater than effective_from when present.

- Only the active policy version may be used for real-time enforcement.

- Enforcement must be checked synchronously during registration and
  re-registration.

- Historical policy rows must remain intact for auditability and dispute
  tracing.

**\## 17.4.Relationships**

- One AccountClosurePenaltyPolicy may govern many
  NationalIdCooldownLedger entries.

- One ledger entry must reference the policy version used during
  evaluation.

- The policy is read by enforcement logic and should not be mutated by
  ledger writes.

- The policy supports versioning across progressive penalty schemes.

**\## 17.5.Indexes**

- PRIMARY KEY (policy_id)

- UNIQUE KEY uq_account_closure_penalty_policy_code (policy_code)

- UNIQUE KEY uq_account_closure_penalty_family_stage (policy_family_code, penalty_stage)

- KEY idx_account_closure_penalty_active (is_active, effective_from,
  effective_to)

**18. CountryActiveUserCounter**

**18.1. Definition**

A real-time materialized counter table storing the active, registered
user count for each Country. Employs a natural Shared PK with Country,
eliminating the need for service-layer polymorphic validation.

**18.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| country_id | SMALLINT UNSIGNED | No | — | PK, FK | Shared PK referencing Country.country_id. |
| active_user_count | BIGINT UNSIGNED | No | 0 | — | Running active user count for this country. |
| updated_at | DATETIME(0) | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | — | UTC timestamp of last update. |

**18.3. Constraints & Business Rules**

- country_id is a Shared Primary Key and a Foreign Key referencing
  Country.country_id, ON DELETE RESTRICT.

- One counter row must be created atomically at the moment of Country
  creation (1:1 mandatory relationship).

- active_user_count must never become negative; enforced via atomic
  UPDATE ... WHERE active_user_count \>= \<decrement_amount\>.

- Lock order rank: $`4`$(locked last in any multi-level transaction) —
  Settlement($`1`$) → County($`2`$) → Province($`3`$) → Country($`4`$).

**18.4. Relationships**

- country_id → Country.country_id (1:1, Shared PK/FK, ON DELETE RESTRICT
  and ON UPDATE RESTRICT).

**18.5. Indexes**

- PRIMARY KEY: (country_id)

- INDEX: idx_cauc_count_desc (active_user_count DESC)

**19. ProvinceActiveUserCounter**

**19.1. Definition**

A real-time materialized counter table storing the active, registered
user count for each Province. Employs a natural Shared PK with Province.

**19.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| province_id | SMALLINT UNSIGNED | No | — | PK, FK | Shared PK referencing Province.province_id. |
| active_user_count | BIGINT UNSIGNED | No | 0 | — | Running active user count for this province. |
| updated_at | DATETIME(0) | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | — | UTC timestamp of last update. |

**19.3. Constraints & Business Rules**

- province_id is a Shared Primary Key and Foreign Key referencing
  Province.province_id, ON DELETE RESTRICT.

- One counter row must be created atomically at the moment of Province
  creation (1:1 mandatory relationship).

- active_user_count must never become negative; enforced via atomic
  guarded UPDATE.

- Lock order rank: $`3`$— acquired after Settlement($`1`$) and
  County($`2`$), before Country($`4`$).

**19.4. Relationships**

- province_id → Province.province_id (1:1, Shared PK/FK, ON DELETE
  RESTRICT and ON UPDATE RESTRICT).

**19.5. Indexes**

- PRIMARY KEY: (province_id)

- INDEX: idx_pauc_count_desc (active_user_count DESC)

**20. CountyActiveUserCounter**

**20.1. Definition**

A real-time materialized counter table storing the active, registered
user count for each County. Employs a natural Shared PK with County.

**20.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| county_id | SMALLINT UNSIGNED | No | — | PK, FK | Shared PK referencing County.county_id. |
| active_user_count | BIGINT UNSIGNED | No | 0 | — | Running active user count for this county. |
| updated_at | DATETIME(0) | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | — | UTC timestamp of last update. |

**20.3. Constraints & Business Rules**

- county_id is a Shared Primary Key and Foreign Key referencing
  County.county_id, ON DELETE RESTRICT.

- One counter row must be created atomically at the moment of County
  creation (1:1 mandatory relationship).

- active_user_count must never become negative; enforced via atomic
  guarded UPDATE.

- Lock order rank: $`2`$— acquired after Settlement($`1`$), before
  Province($`3`$) and Country($`4`$).

**20.4. Relationships**

- county_id → County.county_id (1:1, Shared PK/FK, ON DELETE RESTRICT
  and ON UPDATE RESTRICT).

**20.5. Indexes**

- PRIMARY KEY: (county_id)

- INDEX: idx_couauc_count_desc (active_user_count DESC)

**21. SettlementActiveUserCounter**

**21.1. Definition**

A real-time materialized counter table storing the active, registered
user count for each Settlement. Employs a natural Shared PK with
Settlement.

**21.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| settlement_id | SMALLINT UNSIGNED | No | — | PK, FK | Shared PK referencing Settlement.settlement_id. |
| active_user_count | BIGINT UNSIGNED | No | 0 | — | Running active user count for this settlement. |
| updated_at | DATETIME(0) | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | — | UTC timestamp of last update. |

**21.3. Constraints & Business Rules**

- settlement_id is a Shared Primary Key and Foreign Key referencing
  Settlement.settlement_id, ON DELETE RESTRICT.

- One counter row must be created atomically at the moment of Settlement
  creation (1:1 mandatory relationship).

- active_user_count must never become negative; enforced via atomic
  guarded UPDATE.

- Lock order rank: $`1`$— always acquired first in any multi-level
  transaction.

**21.4. Relationships**

- settlement_id → Settlement.settlement_id (1:1, Shared PK/FK, ON DELETE
  RESTRICT and ON UPDATE RESTRICT).

**21.5. Indexes**

- PRIMARY KEY: (settlement_id)

- INDEX: idx_sauc_count_desc (active_user_count DESC)

**22. UserAccount**

**22.1. Definition**

The UserAccount entity manages authentication credentials, account
lockout state, and the operational lifecycle status of a voter account.
It does not store demographic, geographic, or identity-revealing data;
those data reside strictly in UserProfile.

UserAccount is linked to UserProfile through a shared primary key using
user_id, enforcing a strict one-to-one relationship while separating
authentication metadata from personal identity data.

The account_status values are Active, Locked, and Closed. Active and
Locked represent operational account states. Closed is a permanent
terminal state and cannot transition to any other state.

**22.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| user_id | BIGINT UNSIGNED | No | — | Primary key and foreign key referencing UserProfile.user_id in a strict 1:1 shared-primary-key relationship. |
| password_hash | VARCHAR(255) | Yes | NULL | Argon2id secure cryptographic hash of the user’s password. Must be cleared when account_status = ‘Closed’. |
| account_status | VARCHAR(15) | No | ‘Active’ | The operational status of the account. Allowed: ‘Active’, ‘Locked’, ‘Closed’. |
| mfa_required | TINYINT(1) | No | 0 | Multi-Factor Authentication requirement flag. |
| failed_login_count | TINYINT UNSIGNED | No | 0 | Running count of consecutive failed login attempts since the last successful login. |
| lockout_count | INT UNSIGNED | No | 0 | Number of lockout events used for progressive lockout calculation. |
| last_failed_login_at | DATETIME | Yes | NULL | UTC DATETIME of the last failed login attempt. |
| last_locked_at | DATETIME | Yes | NULL | UTC DATETIME of the most recent transition to ‘Locked’. |
| locked_until | DATETIME | Yes | NULL | UTC DATETIME indicating the end of the temporary security lockout window. It must be non-NULL only while account_status = ‘Locked’ and must be NULL when account_status is ‘Active’ or ‘Closed’. |
| password_reset_completed_at | DATETIME | Yes | NULL | UTC DATETIME of the last completed password reset event. |
| password_changed_at | DATETIME | Yes | NULL | UTC DATETIME of the last voluntary password modification. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of account creation. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of the last record update. |

**22.3. Constraints & Business Rules**

Shared Primary Key & Referential Integrity:user_id must serve as both
the Primary Key and the Foreign Key referencing UserProfile.user_id. The
foreign key must be defined with ON UPDATE RESTRICT and ON DELETE
RESTRICT.

Valid Account Status (CHECK Constraint):Must enforce that account_status
is restricted to valid states:CONSTRAINT chk_user_account_status CHECK
(account_status IN (‘Active’, ‘Locked’, ‘Closed’)).

Lockout Coherency (CHECK Constraints):If the account status is marked as
‘Locked’, the expiration DATETIME must not be NULL:CONSTRAINT
chk_locked_requires_until CHECK (account_status \<\> ‘Locked’ OR
locked_until IS NOT NULL). If the account status is ‘Active’ or
‘Closed’, locked_until must be NULL:CONSTRAINT
chk_non_locked_requires_null_until CHECK (account_status = ‘Locked’ OR
locked_until IS NULL).

Temporal Lockout Expiration:A temporary lock is operationally valid only
while locked_until \> CURRENT_TIMESTAMP. If account_status = ‘Locked’
and locked_until \<= CURRENT_TIMESTAMP, the lockout window is considered
expired. During processing of the first subsequent login attempt:

o account_status must transition back to ‘Active’.

o failed_login_count must be reset to 0.

o locked_until must be set to NULL.

Lockout Trigger & Scaling Policy:When failed_login_count reaches the
threshold defined by the active SecurityPolicy:

o account_status must be set to ‘Locked’.

o last_failed_login_at must be set to CURRENT_TIMESTAMP.

o lockout_count must be incremented by 1.

o last_locked_at must be set to CURRENT_TIMESTAMP.

o locked_until must be calculated using the active SecurityPolicy values
base_lockout_seconds, progressive_factor, and max_lockout_seconds.

o the lockout duration must be calculated as:LEAST(base_lockout_seconds
\* POW(progressive_factor, lockout_count - 1), max_lockout_seconds).

Account Lifecycle Finality (Closed State):Transitioning account_status
to ‘Closed’ is permanent and irreversible. A Closed account must never
transition back to Active or Locked.

The transition to ‘Closed’ is permitted from either Active or Locked and
must be executed as part of the atomic voluntary account closure flow,
including NationalIdCooldownLedger update, UserProfile anonymization,
UserProfile.is_active = 0, AuthSession invalidation, clearing
failed_login_count, clearing lockout_count, clearing
last_failed_login_at, clearing last_locked_at, clearing locked_until,
clearing password_hash, anonymizing all associated UserBiometricCredential records in place, and preserving the UserProfile geographic hierarchy fields (settlement_id, county_id, province_id, country_id). Physical deletion of biometric records is prohibited.

Biometric and Geographic Data Handling on Closure: Sensitive biometric credential fields are set to NULL, is_anonymized is set to 1, and anonymized_at is populated. Geographic hierarchy references in UserProfile are preserved.

. Login and session issuance must be rejected for accounts in Locked or
Closed status.

**22.4. Relationships**

• One-to-One with UserProfile (Dependent Relation):

UserAccount.user_id (PK/FK) references UserProfile.user_id (PK) in a
shared primary key pattern.

On Update: Restrict \| On Delete: Restrict.

**22.5. Indexes**

• PRIMARY KEY: user_id.

• INDEX: idx_user_account_status on (account_status, locked_until) to
optimize login state verification.

**23. SecurityPolicy**

**23.1. Definition**

The SecurityPolicy entity defines the system-wide authentication
security configuration, including maximum login failures, lockout
cooling-off periods, and progressive lockout penalty rules. This
decouples dynamic security configurations from hardcoded application
logic.

Only one SecurityPolicy record may be active for the entire system at
any given time, and the active policy is used by the application layer
during user login operations and account lockout calculations.

**23.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| policy_id | TINYINT UNSIGNED | No | — | Primary Key. Auto-incremented policy identifier. |
| is_active | TINYINT(1) | No | 0 | Flag indicating whether this policy is the single currently active system-wide rule. |
| max_failed_attempts | TINYINT UNSIGNED | No | 5 | Max consecutive failed login attempts allowed before trigger-locking the account. |
| base_lockout_seconds | INT UNSIGNED | No | 900 | Base duration (in seconds) for the first lockout penalty (Default: 15 minutes). |
| progressive_factor | DECIMAL(3,1) | No | 2.0 | Multiplier applied to the lockout duration for subsequent lockouts in a progressive sequence. |
| max_lockout_seconds | INT UNSIGNED | No | 86400 | The ceiling duration for progressive lockouts (Default: 24 hours). |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME when this policy version was registered. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of the last policy metadata modification. |

**23.3. Constraints & Business Rules**

Single Active Policy Constraint:Only a single policy record can be
active (is_active = 1) in the database at any given time. This is
enforced at the database level using a generated stored column and a
unique index:is_active_1 TINYINT GENERATED ALWAYS AS (CASE WHEN
is_active = 1 THEN 1 ELSE NULL END) STORED with a UNIQUE INDEX on
is_active_1.

Numeric Safety Bounds (CHECK Constraints):

o CONSTRAINT chk_policy_max_failed CHECK (max_failed_attempts \> 0)

o CONSTRAINT chk_policy_base_lockout CHECK (base_lockout_seconds \> 0)

o CONSTRAINT chk_policy_progressive_factor CHECK (progressive_factor \>=
1.0)

o CONSTRAINT chk_policy_max_lockout CHECK (max_lockout_seconds \>=
base_lockout_seconds)

Immutability of Policies:A policy record must be treated as immutable
after creation to guarantee trace stability. Any policy change must be
implemented by creating a new policy record and shifting the is_active
flag through an atomic activation operation so that only one policy
remains active.

Lockout Calculation Contract:The active SecurityPolicy must be used by
UserAccount lockout logic to:

o compare failed_login_count against max_failed_attempts.

o calculate the temporary lockout duration using base_lockout_seconds
and progressive_factor.

o enforce max_lockout_seconds as the upper bound on the calculated
lockout duration.

**23.4. Relationships**

• None direct. This table acts as a global singleton configuration state
accessed by the application layer during user login operations and
account lockout calculations.

**23.5. Indexes**

• PRIMARY KEY: policy_id.

• UNIQUE INDEX: idx_unique_active_policy on (is_active_1) to physically
enforce that only one row contains is_active = 1.

**\# 24. UserLoginAuditLog**

**\## 24.1. Definition**

The UserLoginAuditLog entity captures all successful and unsuccessful
authentication attempts. By storing client IP addresses, user agents,
and failure reasons in this specialized append-only table, it provides a
comprehensive forensic trail for anomaly detection (such as brute force
or credential stuffing) without bloating the operational UserAccount
table.

**\## 24.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **log_id** | BIGINT UNSIGNED | No | — | Primary Key. Auto-incrementing identifier. |
| **user_id** | BIGINT UNSIGNED | No | — | Foreign Key referencing UserAccount.user_id. |
| **attempted_at** | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of the login attempt. |
| **login_status** | VARCHAR(15) | No | — | Outcome of the authentication attempt. Allowed: ‘Success’, ‘Failed’. |
| **failure_reason** | VARCHAR(50) | Yes | NULL | Details if failed. Allowed: ‘InvalidPassword’, ‘AccountLocked’, etc. |
| **ip_address** | VARCHAR(45) | No | — | Client IP address (supports IPv4 and IPv6 notations). |
| **user_agent** | VARCHAR(512) | No | — | Raw User-Agent string from the client header. |

**\## 24.3. Constraints & Business Rules**

1.  **Append-Only Enforcement:**This entity must be strictly write-once.
    The database configuration, triggers, or application-level
    privileges must prevent UPDATE and DELETE queries on this table.

2.  **Login Outcome Validity (CHECK Constraints):**

    - CONSTRAINT chk_audit_login_status CHECK (login_status IN
      ('Success', 'Failed'))

    - CONSTRAINT chk_audit_failure_coherency CHECK ((login_status =
      'Failed' AND failure_reason IS NOT NULL) OR (login_status =
      'Success' AND failure_reason IS NULL))

3.  **RESTRICT Deletion Policy:** User login audit logs must be retained
    and must not be deleted when a user account is voluntarily closed or
    transitioned to the Closed state. The foreign key from
    UserLoginAuditLog to UserAccount uses ON DELETE RESTRICT, preventing
    deletion of the UserAccount record while associated login logs
    exist.

**\## 24.4. Relationships**

• UserLoginAuditLog.user_id ➡ UserAccount.user_id (Many-to-one
relationship; foreign key constrained with ON DELETE RESTRICT and ON
UPDATE RESTRICT)

**\## 24.5. Indexes**

- **PRIMARY KEY:** log_id.

- **INDEX:** idx_audit_user_attempts on (user_id, attempted_at) to
  support rapid lockout threshold scans and brute force checks.

- **INDEX:** idx_audit_ip_attempts on (ip_address, attempted_at) to
  detect network-wide distributed brute force attacks.

**\# 25. UserBiometricCredential**

**\## 25.1. Definition**

UserBiometricCredential stores public-key authentication material and
cryptographic identifiers for biometric-backed FIDO/WebAuthn
authentication. The database acts strictly as a public-key signature
verifier. No raw biometric samples, biometric images, or biometric
feature templates are ever transmitted to or stored in the database.

A user profile may register multiple biometric credentials across
multiple devices. However, at any given time, **only one credential may
remain active** for a user. When a new biometric credential is
activated, all previously active credentials of the same user must be
automatically deactivated. In the current policy, the active credential
is also treated as the default credential.

**\## 25.2. Attributes**

| **Column** | **Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **biometric_credential_id** | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Physical primary key. |
| **user_id** | BIGINT UNSIGNED | No | — | Foreign key referencing UserProfile.user_id . |
| **credential_id** | VARBINARY(255) | Yes | — | Hardware identifier returned during credential registration. |
| **device_identifier** | VARCHAR(128) | Yes | NULL | Device tracking code. |
| **device_model** | VARCHAR(100) | Yes | NULL | Device hardware model. |
| **aaguid** | BINARY(16) | Yes | NULL | Authenticator Attestation GUID identifying device make. |
| **public_key** | BLOB | Yes | — | Public key used to verify user-generated signatures. |
| **public_key_sha256** | BINARY(32) | Yes | — | SHA-256 hash of the public key for indexing and fast lookup. |
| **key_algorithm** | VARCHAR(15) | Yes | — | Cryptographic algorithm. Allowed: ‘ES256’, ‘RS256’, ‘Ed25519’. |
| **is_active** | TINYINT(1) | No | 0 | Active key flag. |
| **is_default** | TINYINT(1) | No | 0 | Indicates if this is the default fallback biometric device. |
| **sign_count** | INT UNSIGNED | No | 0 | Anti-replay and cloning prevention counter. |
| **active_user_id** | BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN user_id ELSE NULL END) STORED | Yes | — | Generated column used to enforce that only one active credential may exist per user. |
| **default_user_id** | BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN is_default = 1 THEN user_id ELSE NULL END) STORED | Yes | — | Generated column enforcing a single default biometric device per user. |
| **last_used_at** | DATETIME | Yes | NULL | Last successful biometric login DATETIME. |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | Record creation DATETIME (UTC). |
| **updated_at** | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Auto-updated using ON UPDATE CURRENT_TIMESTAMP. |
| **is_anonymized** | TINYINT(1) | No | 0 | — | Indicates whether sensitive credential data has been anonymized. |
| **anonymized_at** | DATETIME | Yes | NULL | — | UTC timestamp of in-place anonymization. |

**\## 25.3. Constraints and Security Rules**

1.  **Zero Biometric Storage Policy:**Storing raw biological features or
    custom templates is strictly prohibited. The system acts solely as a
    public-key validation registry verifying asymmetrical signatures.

2.  **One Active Key Limit:** A user profile may have at most one active
    biometric credential at any given time. This constraint is
    physically enforced at the database level by a UNIQUE index on the
    generated column active_user_id.

3.  **One Default Key Limit:** A user profile may have at most one
    default biometric credential at any given time. This constraint is
    physically enforced at the database level by a UNIQUE index on the
    generated column default_user_id.

4.  **Active/Default Alignment Rule:** Under the current biometric
    policy, the active credential must also be the default credential.
    Credential activation must atomically deactivate all previously
    active/default credentials of the same user and promote the new
    credential as both active and default.

5.  **Key Algorithm Restriction:**The key_algorithm attribute shall be
    restricted to the supported biometric key algorithms:CONSTRAINT
    chk_biometric_key_algorithm CHECK (key_algorithm IN ('ES256',
    'RS256', 'Ed25519')).

6.  **Anti-Replay Counter Checks:**During assertion, the incoming
    signature counter from the client must be strictly greater than the
    stored sign_count unless both values are zero. The database updates
    sign_count atomically on successful login.

**\## 25.4. Relationships**

- UserProfile: Many-to-One referencing user_id (ON DELETE RESTRICT ON
  UPDATE RESTRICT).

**\## 25.5. Indexes**

- **PRIMARY KEY:** (biometric_credential_id)

- **UNIQUE KEY:** uq_biometric_credential_id on (credential_id)

- **UNIQUE KEY:** uq_biometric_one_active_per_user on (active_user_id)

- **UNIQUE KEY:** uq_biometric_one_default_per_user on (default_user_id)

- **INDEX:** idx_biometric_user_active_lookup on (user_id, is_active)

- **INDEX:** idx_biometric_pubkey_hash on (public_key_sha256)

- **INDEX:** idx_biometric_device_tracing on (device_identifier)

**\# 26. AuthSession**

**\## 26.1. Definition**

AuthSession represents authentication sessions issued to users after
successful identity and credential validation. It stores both active and
terminal sessions until archival. Each user may have at most one
persisted session in Active state at any time. The entity governs
issuance, absolute expiration, inactivity-based termination, revocation,
and optional explicit logout. To support forensic auditability and
session hijacking detection, each session records client IP address and
User-Agent. Terminal sessions are periodically transferred to
auth_session_archives based on terminated_at, which is the authoritative
UTC DATETIME at which the session ceased to be valid.

**\## 26.2. Attributes**

| **Column** | **Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| auth_session_id | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Physical primary key. |
| session_uuid | BINARY(16) | No | — | UUID v7 stored in binary form for API-layer session identification and token representation. |
| user_id | BIGINT UNSIGNED | YES | — | FK referencing UserProfile.user_id. |
| authentication_method | VARCHAR(20) | No | — | Initial authentication method. Allowed values: ‘Password’, ‘Biometric’, or ‘Guest’.. |
| state | VARCHAR(20) | No | 'Active' | Persisted session state. FK referencing auth_session_state_lookup.state_code. |
| active_user_id | BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN state = 'Active' AND user_id IS NOT NULL THEN user_id ELSE NULL END) STORED | Yes | — | Generated enforcement value for authenticated sessions; Guest session uniqueness is managed by the application context. |
| ip_address | VARCHAR(45) | No | — | Client IPv4 or IPv6 address captured for forensic audit. |
| user_agent | VARCHAR(512) | No | — | Client User-Agent string captured for audit and hijacking analysis; not a trusted standalone device identifier. |
| issued_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME at which the session was issued. |
| last_activity_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of the most recent successfully authenticated user interaction; initialized at issuance and updated only while the session remains Active. |
| expires_at | DATETIME | No | — | Absolute UTC expiration DATETIME representing the maximum permitted lifetime of the session. |
| terminated_at | DATETIME | Yes | NULL | Effective UTC DATETIME at which the session ceased to be valid; NULL while the session is Active. |
| revoked_at | DATETIME | Yes | NULL | UTC DATETIME of forced revocation; populated only when state = 'Revoked' and terminal_reason = 'force_revocation'. |
| logged_out_at | DATETIME | Yes | NULL | UTC DATETIME of explicit logout; reserved for trusted internal operations or a future logout API because the current frontend does not expose logout. |
| terminal_reason | VARCHAR(30) | Yes | NULL | Reason for terminal transition. Allowed non-NULL values: 'inactivity_timeout', 'force_revocation', 'manual_logout', 'expired'. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC insertion DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of the most recent persisted change. |

**\### 26.2.1. Lookup Table: auth_session_state_lookup**

| **Attribute** | **Data Type** | **Null** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| state_code | VARCHAR(20) | No | PK | Unique session state code. |
| state_name | VARCHAR(100) | No | — | Human-readable session state name. |
| is_active | TINYINT(1) | No | — | Indicates whether the lookup code is enabled for use; not whether an individual session is active. |
| display_order | INT | No | — | Presentation order. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC insertion DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of the most recent row update. |

**Seed values:**

- Active / Expired / Revoked/ LoggedOut

**\### 26.3. Constraints and Rules**

**\### 26.3.1. Domain Constraints**

- **Authentication Method Restriction:**

- CONSTRAINT chk_auth_session_authentication_method CHECK
  (authentication_method IN ('Password', 'Biometric', 'Guest'))

- **Absolute Expiration Timeline:**

CONSTRAINT chk_auth_session_expiry_timeline CHECK (expires_at \>
issued_at)

- **Last Activity Timeline:**

CONSTRAINT chk_auth_session_last_activity_timeline CHECK
(last_activity_at \>= issued_at AND last_activity_at \<= expires_at)

- **Terminal Reason Allowed Values:**

CONSTRAINT chk_auth_session_terminal_reason CHECK (terminal_reason IS
NULL OR terminal_reason IN ('inactivity_timeout', 'force_revocation',
'manual_logout', 'expired'))

- **Session State and Terminal-Metadata Consistency:**

CONSTRAINT chk_auth_session_terminal_state CHECK ((state = 'Active' AND
terminal_reason IS NULL AND terminated_at IS NULL AND revoked_at IS NULL
AND logged_out_at IS NULL ) OR ( state = 'Expired' AND terminal_reason
IN ('expired', 'inactivity_timeout')

AND terminated_at IS NOT NULL AND revoked_at IS NULL AND logged_out_at
IS NULL ) OR ( state = 'Revoked' AND terminal_reason =
'force_revocation' AND terminated_at IS NOT NULL AND revoked_at IS NOT
NULL AND logged_out_at IS NULL AND revoked_at = terminated_at ) OR (
state = 'LoggedOut' AND terminal_reason = 'manual_logout' AND
terminated_at IS NOT NULL AND revoked_at IS NULL AND logged_out_at IS
NOT NULL AND logged_out_at = terminated_at ) )

- **General Termination Timeline:**

CONSTRAINT chk_auth_session_terminated_at_timeline CHECK (terminated_at
IS NULL OR ( terminated_at \>= issued_at AND terminated_at \<=
expires_at AND terminated_at \>= last_activity_at ) )

- **Revocation Timeline:**

CONSTRAINT chk_auth_session_revoked_at_timeline CHECK ( revoked_at IS
NULL OR (revoked_at \>= issued_at AND revoked_at \<= expires_at) )

- **Explicit Logout Timeline:**

CONSTRAINT chk_auth_session_logged_out_at_timeline CHECK ( logged_out_at
IS NULL OR (logged_out_at \>= issued_at AND logged_out_at \<=
expires_at) )

**\### 26.3.2. Immutability & Lifecycle Rules**

- auth_session_id, session_uuid, user_id, issued_at, and
  authentication_method are immutable after creation.

- last_activity_at must be initialized to issued_at when the session is
  created and must never be NULL.

- A user may have at most one session whose persisted state is Active.
  This invariant is enforced at the database level through
  active_user_id and UNIQUE KEY uq_auth_session_active_user.

- Before issuing a new session, the transaction service must lock and
  evaluate any existing Active session of the same user. If it is no
  longer valid due to absolute expiration or inactivity, it must first
  be transitioned to terminal state. If business rules permit
  replacement of a still-valid session, the previous session must first
  be atomically transitioned to Revoked with terminal_reason =
  'force_revocation'.

- Once a session enters Expired, Revoked, or LoggedOut, it must never
  transition back to Active. A new authentication event must create a
  new AuthSession record.

- expires_at is the source of truth for absolute maximum session
  lifetime. The application must treat the session as invalid whenever
  CURRENT_TIMESTAMP \>= expires_at, even if state has not yet been
  asynchronously updated.

- An Active session must be treated as invalid when CURRENT_TIMESTAMP
  \>= last_activity_at + INTERVAL 15 MINUTE, provided it has not already
  reached expires_at.

- When inactivity termination is persisted, the session must be updated
  to state = 'Expired', terminal_reason = 'inactivity_timeout', and
  terminated_at = last_activity_at + INTERVAL 15 MINUTE; revoked_at and
  logged_out_at must remain NULL.

- An \`Active\` session must be considered invalid once
  \`CURRENT_TIMESTAMP \>= last_activity_at + INTERVAL 15 MINUTE\`,
  unless it has already reached \`expires_at\` earlier.
  \`last_activity_at\` may be updated only by a successfully
  authenticated request, action, or server-accepted heartbeat
  attributable to that same session. Therefore, if the user has left the
  application environment and no qualifying session activity is recorded
  for 15 consecutive minutes, the session must be terminated as
  \`Expired\` with \`terminal_reason = 'inactivity_timeout'\` and
  \`terminated_at = last_activity_at + INTERVAL 15 MINUTE\`. During this
  transition, \`revoked_at\` and \`logged_out_at\` must remain NULL. The
  absence of an explicit logout capability in the current frontend does
  not extend session validity beyond this inactivity threshold.

- Only a user-initiated request or a server-accepted heartbeat generated
  while the client is in an active foreground page-interaction state may
  advance \`last_activity_at\`. Any heartbeat produced while the client
  is backgrounded, hidden, suspended, detached, or otherwise
  non-interactive shall be ignored for session-liveness purposes.
  Consequently, if no qualifying interactive activity is recorded for 15
  consecutive minutes after the user exits the application environment,
  the session must be marked \`Expired\` with \`terminal_reason =
  'inactivity_timeout'\` and \`terminated_at = last_activity_at +
  INTERVAL 15 MINUTE\`.

- When absolute expiration is persisted, the session must be updated to
  state = 'Expired', terminal_reason = 'expired', and terminated_at =
  expires_at.

- last_activity_at may be refreshed only after a successfully
  authenticated request and only if the session is still valid and still
  Active.

- Session validation, inactivity evaluation, expiration evaluation, and
  last_activity_at refresh must be concurrency-safe and atomic at the
  transaction or conditional-update level.

- A background worker may reconcile stale persisted Active sessions into
  Expired, but this worker is only a reconciliation mechanism; every
  authenticated API request must independently enforce expiration and
  inactivity timeout.

- **Guest-to-User Upgrade Protocol:** Upon successful completion of user
  registration during an active Guest session, the transaction service
  must perform an atomic update to promote the existing session. The
  user_id must be updated from NULL to the new user_id, and
  authentication_method must transition from 'Guest' to the verified
  credential type ('Password' or 'Biometric'). To preserve session
  continuity and maintain the session_uuid and issued_at integrity,
  these immutable attributes must remain unchanged.

- **Atomic Session Replacement (Single Active Session Invariant):**
  Prior to issuing or activating any new session (whether a Guest
  session or a User session), the system must atomically identify and
  invalidate any existing Active session for the target user_id (or, in
  the case of Guest sessions, the current non-authenticated context). If
  an Active session exists, it must be immediately transitioned to the
  Revoked state with terminal_reason = 'force_revocation', revoked_at =
  CURRENT_TIMESTAMP, and terminated_at = revoked_at. This ensures the
  system maintains exactly one active session per user profile at any
  given time.

- **Upgrade State Invariant:** Session promotion is strictly restricted
  to sessions in the Active state. The system must validate the session
  state prior to the upgrade transaction. If the Guest session has
  already transitioned to Expired, Revoked, or LoggedOut (due to
  inactivity, absolute expiration, or previous revocation), the upgrade
  must be rejected, and the system must return a SessionExpired error.
  No dormant or terminated session may be promoted to an authenticated
  user session.

- The current frontend does not expose logout. Therefore, LoggedOut,
  logged_out_at, and terminal_reason = 'manual_logout' are reserved for
  trusted internal operations or a future explicit logout API.

- Administrative revocation, security-triggered invalidation, or
  replacement by a newly issued session must transition the previous
  session to Revoked with terminal_reason = 'force_revocation',
  revoked_at = effective revocation DATETIME, and terminated_at =
  revoked_at.

**\### 26.3.3. Archival Policy**

Sessions in a terminal state whose terminated_at is older than 6 months
must be transferred from AuthSession to auth_session_archives through a
controlled archival process. terminated_at is the authoritative archival
reference; expires_at must not be used as a substitute because a session
may terminate earlier due to inactivity, revocation, or explicit logout.
Only sessions in Expired, Revoked, or LoggedOut state with non-NULL
terminated_at are eligible for archival. Active sessions must never be
archived.

**\## 26.4. Relationships**

- **UserProfile:** Many AuthSession records belong to one UserProfile
  through AuthSession.user_id → UserProfile.user_id (ON DELETE RESTRICT
  ON UPDATE RESTRICT).

- **Auth Session State Lookup:** Many AuthSession records reference one
  auth_session_state_lookup row through AuthSession.state →
  auth_session_state_lookup.state_code (ON DELETE RESTRICT ON UPDATE
  RESTRICT).

- **Generated Enforcement Column:** active_user_id is a generated
  enforcement column only; it does not create an independent
  relationship and must not have a separate foreign key.

**\## 26.5. Indexes**

- PRIMARY KEY (auth_session_id)

- UNIQUE KEY uq_auth_session_uuid (session_uuid)

- UNIQUE KEY uq_auth_session_active_user (active_user_id)

- INDEX idx_auth_session_user_state (user_id, state)

- INDEX idx_auth_session_state_expiry (state, expires_at)

- INDEX idx_auth_session_state_activity (state, last_activity_at)

- INDEX idx_auth_session_user_activity (user_id, last_activity_at)

- INDEX idx_auth_session_archival_lookup (state, terminated_at)


**27. SystemState**

**27.1. Definition**

SystemState is a singleton governing entity that stores the global
operational status of the platform. It contains exactly one persistent
row and enforces sequential, non-reversible (monotonic) transitions
between states 1 and 7 to control system-wide capability activation.

In this updated version, administrative state changes (State 2 to 7)
reference the official SystemAdmin record rather than a general
UserProfile.user_id, establishing a clean boundary between the civilian
user database and the administrative authority plane.

**27.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key Role** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| system_state_id | TINYINT UNSIGNED | No | 1 | PK | Singleton primary key. Must always equal 1. |
| state_value | TINYINT UNSIGNED | No | — | FK | Current system state (1 to 7). References system_state_lookup.state_code. |
| root_country_id | SMALLINT UNSIGNED | No | 1 | FK | References CountryActiveUserCounter.country_id; identifies the root/national scope used for activation threshold tracking. |
| activation_user_threshold | BIGINT UNSIGNED | No | 44000000 | — | Minimum user threshold for state 1 to 2 transition. Default: 44,000,000. |
| breathing_period_hours | INT UNSIGNED | No | 24 | — | Cooling interval before state 1 to 2 transition can occur. Default: 24. |
| threshold_reached_at | DATETIME | Yes | NULL | — | UTC DATETIME when the country’s active user count first met the activation threshold. |
| state_changed_at | DATETIME | No | — | — | UTC DATETIME of the last state transition. |
| changed_by_admin_id | TINYINT UNSIGNED | Yes | NULL | FK | Reference to the administrator’s identity (SystemAdmin.admin_id) who authorized the manual transition. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | — | Record creation DATETIME (UTC). |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | — | Last modification DATETIME (UTC). |

**27.2.1. Lookup Table: system_state_lookup**

| **Attribute** | **Data Type** | **Null** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| state_code | TINYINT UNSIGNED | No | PK | Unique state identifier (1 to 7). |
| state_name | VARCHAR(100) | No | — | Persian/English representation of the system operational phase. |
| description | VARCHAR(255) | Yes | — | Operational rules and permissions enforced during this phase. |

- **Seed Values for system_state_lookup**:

  - 1: Activation phase, waiting for initial threshold

  - 2: Referendum ready state

  - 3: First Presidential Election

  - 4: First Provincial/State Elections

  - 5: First County/Governorship Elections

  - 6: First Municipal Elections

  - 7: System completely deployed/finalized

**27.3. Constraints and Business Rules**

- **Singleton Enforcement**:CONSTRAINT chk_system_state_singleton CHECK
  (system_state_id = 1)

- **Administrator Transition Requirement**:CONSTRAINT
  chk_admin_required_for_manual CHECK (state_value = 1 OR (state_value
  \> 1 AND changed_by_admin_id IS NOT NULL))

- **Monotonic State Progression**: State transitions must strictly move
  forward (e.g., (1 \to 2 \to 3)). Transitions backward must be blocked
  at database trigger level (BEFORE UPDATE) and application service
  tier.

- **State 1 to 2 Threshold Rule**: Activation requires root country
  active user count matching or exceeding activation_user_threshold
  followed by the specified cooling-off duration defined by
  breathing_period_hours.

**27.4. Relationships**

- system_state_lookup: Many-to-One referencing state_value (\to)
  system_state_lookup.state_code (ON DELETE RESTRICT ON UPDATE
  RESTRICT).

- CountryActiveUserCounter: Many-to-One root_country_id (\to)
  CountryActiveUserCounter.country_id (ON DELETE RESTRICT ON UPDATE
  RESTRICT).

- SystemAdmin: Many-to-One referencing changed_by_admin_id (\to)
  SystemAdmin.admin_id (ON DELETE RESTRICT ON UPDATE RESTRICT).

**27.5. Indexes**

- PRIMARY KEY (system_state_id)

- INDEX idx_system_state_value (state_value)

- INDEX idx_system_state_country (root_country_id)

- INDEX idx_system_state_admin (changed_by_admin_id)
