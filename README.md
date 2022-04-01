# Chillbox

_Work in Progress_

Infrastructure for websites that use Chill and custom Python Flask services.

## Goals

- Simple
- Less overhead
- Support local development
    - Containers are only used for local development
- Share resources for multiple web sites and their services on a single server
- Efficient serving of static files which are backed by S3 object storage
- Artifacts and configurations are immutable and are used for deployments
- Applications run in an recent Alpine Linux image

## Non-goals

- Scaling out to multiple servers
- No containers in Production
- High availability
- Relational Databases shared between applications


TODO Add chillbox overview graphic
