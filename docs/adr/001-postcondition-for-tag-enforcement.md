# ADR 001: Use Terraform postcondition instead of precondition for tag enforcement

## Status

Accepted

## Context

The IDP platform needed a way to guarantee that every provisioned resource carries a minimum set of tags (team, environment, cost-center), since downstream systems depend on this: the AWS Budget cost-tracking guardrail filters spend by these exact tags, and consistent tagging is required for any real cost attribution to work.

Terraform's lifecycle block supports two mechanisms for this kind of validation: precondition and postcondition. The initial implementation used precondition, referencing self.tags to check whether required tags were present before allowing the resource to be created.

## Decision

Use postcondition instead of precondition for this check.

## Why

A precondition is evaluated before Terraform has computed the resource's final attributes. The self object, which refers to the resource's own attributes, is not available in a precondition context, since the resource does not exist yet at that point in evaluation. Attempting to reference self.tags inside a precondition produces a hard error: "The self object is not available in this context."

A postcondition is evaluated after Terraform knows the resource's final attributes, whether the resource is being newly created or updated. This makes self a valid reference, and it is the conceptually correct choice here: the actual requirement is "verify the resource that is about to exist has these tags," which is a check on the result, not a check on the inputs.

## Consequences

This was discovered through a real validate error during development, not anticipated in advance. It is a useful distinction to internalize: precondition is for validating assumptions and inputs before an action, such as confirming an AMI exists or a variable is within an expected range. postcondition is for validating the actual outcome of an action, such as confirming a created resource has the properties it was expected to have.

Any future guardrail that needs to inspect a resource's own computed attributes, rather than external inputs, should default to postcondition rather than precondition.
