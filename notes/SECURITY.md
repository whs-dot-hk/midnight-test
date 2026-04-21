# Key storage
## HSM
* Best fit for validator mode when the signing path supports remote signing.
* Pros: Private keys stay in dedicated hardware and never touch node disk.
* Pros: Strong key protection, audit controls, and tamper resistance.
* Cons: Higher cost and operational complexity.
* Cons: Requires integration support from the validator signing workflow.
* Cons: Machine out of order the private key gone.
## KMS
* Pros: Private keys are managed outside the validator host.
* Pros: The validator can request signing operations without local key files.
* Cons: Requires validator/plugin support for KMS signing.
* Cons: Adds cloud/API dependency and possible signing latency.
## Secrets manager
* Pros: Central place to store and rotate validator secrets.
* Pros: Works well with IaC and bootstrap automation.
* Cons: In validator mode, the private key is still loaded into node memory for signing from plaintext file.
* Cons: Weaker isolation than HSM/KMS remote signing.

## Key rotation (minimal disruption)
Keep old and new keys active briefly: generate/verify new key (prefer HSM/KMS), register new public key, switch node to new key in a low-traffic window, monitor signing/peering, then revoke and destroy old key after stability.

Risks: propagation delay, misconfiguration, key exposure, and no rollback path. Mitigations: overlap window, staged/canary cutover, strict access controls, and a tested rollback to old key.

## Incident response (suspected key exposure)
* Contain now: pause signing and lock access to the suspected key to limit blast radius.
* Revoke + rotate: revoke the old key, issue a new key in HSM/KMS, and update trust/config quickly.
* Investigate + notify: scope impacted artifacts/logs, preserve evidence, and communicate required actions. Take a snapshot of the disk. Find blocks that maybe affected.
