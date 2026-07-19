
# Internal Developer Platform (IDP)
A self-service platform enabling engineering teams to provision cloud infrastructure through a PR-based workflow -no tickets to platform team,no manual AWS console work.

## Overview
Engineers request environments by submitting a PR to a YAML config file. CI validates the request, Terraform provisions the infrastructure, and the requesting team receives a URL and  credentials automatically - with built-in guardrails (cost caps, mandatorry tagging, production approval gates).

## Status
 Actively in development - building in public, ticket by ticket.

## Architecture
 Diagram and full write-up coming as components are built.

## Tech Stack
- **IaC:** Terraform
- **CI/CD:** Github Actions
- **Cloud:** AWS
- **Guardrails:** cost caps , tagging enforcement, prod approval gates

## Project Board
See '/docs' for runbooks and architecture decision records (ADRs).

