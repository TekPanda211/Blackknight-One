# Changelog

All notable changes to BlackKnight One are documented in this file.

The project follows the principles of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses Semantic Versioning.

---

## [0.7.0] - 2026-07-14

### Added

#### Platform

- Introduced the interactive `Show-BKDashboard` as the primary platform entry point.
- Added menu-driven navigation for Terraform, Microsoft Graph, reporting, and platform functions.
- Added tenant selection prior to Microsoft Graph operations.
- Added centralized platform wrapper architecture.

#### Terraform

- Added Complete Terraform Assessment Engine.
- Added Terraform HCL Discovery Engine v2.
- Added Terraform Security Analysis Engine.
- Added Terraform Architecture Analysis.
- Added Terraform dependency discovery.
- Added Terraform version constraint discovery.
- Added Terraform graph analysis.
- Added Terraform architecture scoring.
- Added Terraform security scoring.
- Added JSON export for all Terraform assessment engines.

#### Terraform Assessment

- Added multi-phase assessment workflow consisting of:
  - Inventory
  - HCL Discovery
  - Security Analysis
  - Configuration Validation
  - Execution Plan Analysis
  - Two-Phase Drift Confirmation
- Added executive assessment summaries.
- Added confidence scoring.
- Added release decision recommendations.
- Added consolidated findings collection.

#### Drift Detection

- Introduced Two-Phase Drift Detection.
- Added refresh-only observation phase.
- Added confirmation plan phase.
- Eliminated false-positive drift caused by provider normalization.
- Added differentiation between state observations and actionable infrastructure drift.

#### Microsoft Graph

- Added Tenant Discovery Engine.
- Added Microsoft Graph Assessment Engine.
- Added organization discovery.
- Added domain discovery.
- Added user inventory.
- Added group inventory.
- Added device inventory.
- Added service principal inventory.
- Added license inventory.
- Added executive assessment reporting.

#### Reporting

- Added executive assessment summaries.
- Added standardized findings model.
- Added confidence scoring.
- Added assessment health indicators.
- Added JSON report generation.
- Added release recommendations.

### Changed

#### Platform

- Dashboard is now the recommended entry point instead of individual PowerShell cmdlets.
- Standardized wrapper architecture across all platform engines.
- Standardized assessment object model.
- Improved verbose logging across assessment workflows.

#### Terraform

- Improved HCL parsing performance.
- Improved dependency discovery.
- Improved assessment scoring.
- Improved architecture reporting.
- Improved assessment consistency between engines.

#### Security

- Security Analyzer now automatically refreshes HCL discovery with source information when required.
- Improved handling of missing source data.
- Reduced duplicate parsing operations.

#### Microsoft Graph

- Improved assessment consistency.
- Improved reporting structure.
- Improved executive summaries.

### Fixed

#### Terraform

- Fixed refresh-only drift producing false-positive assessment findings.
- Fixed assessment failures caused by empty drift severity values.
- Fixed HCL parsing edge cases involving empty collections.
- Fixed wrapper resolution for Terraform assessment engine.
- Fixed parameter validation failures during assessment execution.
- Fixed security analysis failures caused by missing source information.

#### Platform

- Fixed dashboard command discovery.
- Fixed module import consistency.
- Fixed assessment wrapper execution paths.
- Fixed report generation reliability.

### Documentation

- Rewrote README to reflect the dashboard-first platform experience.
- Added updated Quick Start guidance.
- Updated platform architecture documentation.
- Updated assessment workflow documentation.

---

## [0.6.0] - Previous Release

### Added

- Initial Terraform Assessment Engine.
- Initial Microsoft Graph discovery components.
- Assessment reporting framework.