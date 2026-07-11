# Access Packages Design

## Purpose

This document describes how Access Packages fit into Microsoft Entra Identity Governance and how they can support scalable access management.

## What Access Packages Solve

Access Packages help organizations provide structured access to groups, applications, and SharePoint resources using request workflows, approvals, expiration, and reviews.

Instead of granting access manually, access can be bundled into a package aligned to a business role, project, persona, or temporary need.

## Core Concepts

### Catalog

A container used to organize access packages and resources.

### Access Package

A bundle of resources a user can request or be assigned.

### Assignment Policy

Defines who can request access, whether approval is required, how long access lasts, and whether reviews are required.

### Resource Roles

The specific permissions included in the package, such as group membership or application assignment.

## Example Access Package Ideas

### Support Engineer Base Access

Resources:

- Support security group
- Knowledge base access
- Ticketing system app assignment
- Internal support documentation

### Contractor Access

Resources:

- Contractor group
- Limited app access
- Expiration after 90 days
- Manager approval required

### Finance Application Access

Resources:

- Finance app assignment
- Finance security group
- Quarterly access review
- Approval from finance owner

## Design Standards

Access Packages should include:

- Clear business purpose
- Named owner
- Approval workflow when appropriate
- Expiration date for temporary access
- Access review for sensitive access
- Documented resources included
- Least-privilege design

## Security Checks

Review each Access Package for:

- Missing owners
- Missing expiration
- Missing approval
- Missing access review
- Broad requester scope
- Sensitive resources without review
- External user access

## Interview Talking Point

Access Packages are powerful because they move access management from one-off manual group assignments into governed, reviewable, and repeatable identity lifecycle workflows.
