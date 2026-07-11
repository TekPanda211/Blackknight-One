\# Identity Governance Engine



\## Purpose



The Identity Governance Engine defines how access is requested, approved, assigned, reviewed, and removed.



This engine focuses on answering one question:



> Can I prove that access is appropriate, approved, time-bound, and reviewable?



\## Core Capabilities



\### Access Packages



Access Packages provide structured, governed access to resources.



They can include:



\- Groups

\- Teams

\- SharePoint sites

\- Enterprise applications

\- Application roles



Access Packages should define:



\- Who can request access

\- Who approves access

\- How long access lasts

\- Whether justification is required

\- Whether access is reviewed

\- What happens when access expires



\## Entitlement Management



Entitlement Management is the governance layer that controls access packages, catalogs, assignment policies, approvals, and expirations.



BlackKnight One uses Entitlement Management to model repeatable access patterns such as:



\- New hire access

\- Department access

\- Contractor access

\- Privileged access

\- Application access

\- Temporary project access



\## Administrative Units



Administrative Units allow scoped administration.



They help separate responsibility across departments, regions, business units, or operational boundaries.



Example Administrative Units:



\- IT

\- Security

\- Engineering

\- HR

\- Finance

\- Contractors



\## Dynamic Groups



Dynamic Groups reduce manual access assignment by using attributes such as department, job title, location, or employee type.



Example:



If a user has Department = Security, they can automatically become a member of the Security Users group.



\## Access Reviews



Access Reviews provide recurring validation that users still require access.



Access Reviews should be used for:



\- Privileged groups

\- Access Packages

\- Guest users

\- Contractors

\- Application access

\- Sensitive business units



\## Lifecycle Workflows



Lifecycle workflows support identity events such as:



\- New hire

\- Internal transfer

\- Promotion

\- Contractor onboarding

\- Contractor expiration

\- Employee offboarding

\- Emergency termination



\## GDAP-Inspired Governance



For partner and delegated administration scenarios, governance should validate:



\- Who has delegated access

\- What role is assigned

\- Whether access is group-based

\- Whether access is time-bound

\- Whether access has an owner

\- Whether access is reviewed

\- Whether access is still required



\## Governance Pattern



Every governed access workflow should follow this model:



1\. Request

2\. Approve

3\. Assign

4\. Validate

5\. Review

6\. Expire

7\. Report



\## BlackKnight One Principle



Access should never be assumed.



Access should be requested, approved, validated, reviewed, and backed by evidence.

