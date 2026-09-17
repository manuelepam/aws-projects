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

## Architecture

```mermaid
flowchart LR
    GitHub[GitHub] --> Jenkins[Jenkins Pipeline]
    Jenkins --> Tests[Tests and Coverage]
    Jenkins --> SonarQube[SonarQube Quality Gate]
    Jenkins --> Trivy[Security Scans]
    Jenkins --> ECR[AWS ECR]
    Jenkins --> Nexus[Nexus Artefact Repository]
    ECR --> Kubernetes[Kubernetes Deployment]
    Kubernetes --> Prometheus[Prometheus]
    Prometheus --> Grafana[Grafana Dashboards]
```

## Deployment Safety


The pipeline blocks deployment when tests, the SonarQube quality gate, dependency auditing, infrastructure scanning, or container vulnerability scanning fails.

Container images use immutable tags containing the short Git commit and Jenkins build number. Build reports and metadata are bundled and uploaded to Nexus, providing traceability from source commit to deployed image.

Kubernetes performs rolling deployments across two replicas. If a rollout fails, Jenkins automatically restores the previous deployment revision and verifies that the original image is running.


## Evidence

### Nexus artefact traceability
![Build artefact stored in Nexus](docs/screenshots/nexus-build-artifact.png)

The Nexus bundle contains build metadata, test results, coverage and security reports. It is uploaded using a dedicated least-privilege Jenkins account.

### Automatic rollback
![Jenkins automatic rollback](docs/screenshots/jenkins-automatic-rollback.png)

A controlled test deploys a deliberately missing image. Kubernetes rejects the rollout, Jenkins restores the previous image, verifies the rollback and reports the test build as failed.

