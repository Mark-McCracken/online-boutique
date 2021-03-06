# Interview - Steps

1. Clone Repo from google repo
1. Sign into Google Cloud Console UI and gcloud SDK
1. Create Terraform bucket
1. Create Initial Infrastructure
1. Get credentials for cluster `gcloud container clusters get-credentials mark-interview-cluster --zone=europe-west2-a`
1. Add kubernetes provider to terraform
1. Add Storage Class, required for Cart Service later for persistent volume.
1. Loosely following the guide in the readme, install skaffold, and run the command to build all items. 
Make use of Google Cloud Build and use eu.gcr.io, as cluster was deployed in EU, and images will be faster to fetch
than gcr.io, which is based in the US. `skaffold run --default-repo=eu.gcr.io/$(gcloud config get-value project)`
1. Import the LoadBalancer service, to use it's IP address:
`terraform import kubernetes_service.frontend default/frontend-external`
1. Import the DNS managed zone, so it can be referenced by the DNS record:
`terraform import google_dns_managed_zone.k8s_careers_mark projects/$(gcloud config get-value project)/managedZones/k8s-careers-mark`
1. Create the DNS record, referencing the managed zone and Load Balancer IP address
1. Modify the redis-cart yaml, adding a PVC, and changing the volume mounted from emptyDir to a PVC
1. Re-run skaffold deployment

## Summary of mistakes...

`terraform init` seemed dead set on using a different set of credentials, despite specifying an `access_token`. 
Had to run `google auth application-default login` which got things going.

Tried to use Google Cloud Source repositories. Can't enabled it, no sufficient permissions.

Initially provisioned a cluster with very strict scopes, meaning it was unable to pull images from container registry.
This doesn't actually require destroying and re-creating a cluster, just the nodes, but terraform in this state, can't
separate the two. This wasn't a problem, but was interesting to see the destroying the cluster did _not_ destroy the
storage class, although it was destroyed as part of the cluster tear-down and re-create.
Terraform seemed to think that after this change was applied, that all work was complete, but immediately running
`terraform plan` again showed that it couldn't find the storage class and needed to provision it again, despite that I
had added a tag saying the storage class depends on the cluster.
Colour me unimpressed and frustrated with terraform, yet again!

Initially created storage class with regional persistent disks on GKE, as these are more resilient, and I typically
use a regional cluster. However, for this deployment I just used a single zone with preemptible nodes to reduce costs.
This meant that there were no other nodes to replicate the disk to, and when provisioned, it could not be attached,
so this had to be re-created.

## Opinions in approach

### Separate slow moving infrastructure from fast moving software

Terraform can be quite nice for someone to read, to understand what components are required to get the project up and
running, even if it isn't always nice to write.

However, I find it to be something a human would be more likely to carefully review and deploy manually, and less
likely to automate.

Also, terraform aims to represent a desired state, but this desired state often requires imperative steps that need to
be performed in order, which can make it difficult deploying the whole thing to a new project.

The components of the software on the other hand, are likely to move much faster, and the need for automation is a lot
greater.

So I tend to use a CI/CD platform for this, such as github actions or google cloud build.

I find this creates a bit of tension between the 2 tools, there will almost certainly be a dependency formed between
them. In this case, we want something concrete like a DNS entry to be specified, dependent on the LoadBalancer's
IP address, requiring manual import.
