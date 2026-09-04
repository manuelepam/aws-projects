# End-to-End DevSecOps CI/CD Platform

This project demonstrates an automated CI/CD pipeline that builds, tests, scans, stores, deploys, and monitors a Python application on AWS.

## Project Goals

- Build infrastructure using Terraform.
- Run automated tests with Jenkins.
- Check code quality with SonarQube.
- Store build artifacts in Nexus.
- Scan code, dependencies, containers, and infrastructure for security problems.
- Deploy the application to Kubernetes.
- Monitor the platform using Prometheus and Grafana.

## Company Scenario

ZephyrWorks Energy is a fictional UK renewable-energy company that operates wind farms. Its engineers rely on a Python application called the Turbine Maintenance API to view turbine conditions and identify equipment requiring maintenance.

## Business Problem

Software releases are currently performed manually, making them slow, inconsistent, and difficult to audit. Testing and security checks can be missed, while failed releases are difficult to reverse. If engineers cannot access accurate turbine information, maintenance may be delayed and electricity generation may be reduced.

## Proposed Solution

This project creates an automated DevSecOps platform that validates every change, stores approved artefacts, deploys repeatable application versions, monitors system health, and supports recovery from failed releases.

## Success Criteria

- Block deployment when tests, quality checks, or security scans fail.
- Trace every deployed artefact to its source-code commit.
- Deploy application updates without planned downtime.
- Recover from a failed release within ten minutes.
- Display application, platform, and business metrics in Grafana.
- Reproduce and safely remove the AWS infrastructure using Terraform.

