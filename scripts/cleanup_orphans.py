import boto3
import os
import sys

def get_all_images(ecr_client, repo_name):
    """
    Returns a set of all image digests in the repository.
    """
    digests = set()
    paginator = ecr_client.get_paginator('list_images')
    try:
        for page in paginator.paginate(repositoryName=repo_name):
            for image in page.get('imageIds', []):
                if 'imageDigest' in image:
                    digests.add(image['imageDigest'])
    except ecr_client.exceptions.RepositoryNotFoundException:
        print(f"Repository {repo_name} not found.")
        sys.exit(1)
    return digests

def get_all_tags(ecr_client, repo_name):
    """
    Returns a list of dicts {imageDigest, imageTag} for all tagged images.
    """
    tags = []
    paginator = ecr_client.get_paginator('list_images')
    try:
        for page in paginator.paginate(repositoryName=repo_name, filter={'tagStatus': 'TAGGED'}):
            for image in page.get('imageIds', []):
                if 'imageTag' in image:
                    tags.append(image)
    except ecr_client.exceptions.RepositoryNotFoundException:
        print(f"Repository {repo_name} not found.")
        sys.exit(1)
    return tags

def get_repositories(ecr_client, namespace):
    """
    Returns a list of repository names that start with the given namespace.
    """
    repos = []
    paginator = ecr_client.get_paginator('describe_repositories')
    for page in paginator.paginate():
        for repo in page['repositories']:
            if repo['repositoryName'].startswith(namespace):
                repos.append(repo['repositoryName'])
    return repos

def main():
    region = os.environ.get('AWS_REGION', 'us-east-1')
    ecr_namespace = os.environ.get('ECR_NAMESPACE')
    sig_repo = os.environ.get('ECR_SIG_REPO')
    dry_run = os.environ.get('DRY_RUN', 'false').lower() == 'true'

    if not ecr_namespace or not sig_repo:
        print("Error: ECR_NAMESPACE and ECR_SIG_REPO environment variables must be set.")
        sys.exit(1)

    ecr = boto3.client('ecr', region_name=region)

    print(f"--- Starting Cleanup in {region} ---")
    print(f"Namespace:  {ecr_namespace}")
    print(f"Sig Repo:   {sig_repo}")
    print(f"Dry Run:    {dry_run}")

    # 1. Find all repos in namespace
    print("Finding repositories in namespace...")
    repos = get_repositories(ecr, ecr_namespace)
    print(f"Found {len(repos)} repositories: {repos}")

    # 2. Get valid digests from ALL App Repos
    valid_digests = set()
    for repo in repos:
        print(f"Fetching digests from {repo}...")
        valid_digests.update(get_all_images(ecr, repo))
    
    print(f"Found {len(valid_digests)} unique valid image digests across all repos.")

    # 3. Get all tags from the Signature Repo
    print("Fetching signature tags...")
    sig_tags = get_all_tags(ecr, sig_repo)
    print(f"Found {len(sig_tags)} signatures/attestations.")

    # 3. Find orphans
    orphans = []
    for sig in sig_tags:
        tag = sig['imageTag']
        
        # Cosign Tag Format Logic:
        # The tag usually starts with "sha256-" followed by the digest.
        # It might have suffixes like ".sig" or ".att".
        # We need to extract the 64-character hash.
        
        # Simple extraction: find the first occurrence of 64 hex chars
        # But standard cosign mapping is: sha256:xxxx -> sha256-xxxx
        
        if tag.startswith('sha256-'):
            # Extract the hash part (remove sha256- prefix)
            # If there are suffixes (like .att), we need to handle them.
            # Usually the hash is the first 64 chars after 'sha256-'
            
            potential_hash = tag[7:71] # 7 is len('sha256-'), 71 is 7+64
            
            # Reconstruct the digest format used in ECR (sha256:xxxx)
            reconstructed_digest = f"sha256:{potential_hash}"
            
            if reconstructed_digest not in valid_digests:
                orphans.append(sig)
        else:
            # If it doesn't match the pattern, we skip it (safe mode)
            print(f"Skipping non-standard tag: {tag}")

    print(f"Found {len(orphans)} orphaned signatures.")

    # 4. Delete orphans
    if orphans:
        if dry_run:
            print("Dry Run: The following tags would be deleted:")
            for o in orphans:
                print(f"  - {o['imageTag']}")
        else:
            print("Deleting orphans...")
            # Batch delete (max 100 at a time)
            batch_size = 100
            for i in range(0, len(orphans), batch_size):
                batch = orphans[i:i+batch_size]
                image_ids = [{'imageTag': o['imageTag'], 'imageDigest': o['imageDigest']} for o in batch]
                
                print(f"Deleting batch {i//batch_size + 1}...")
                response = ecr.batch_delete_image(
                    repositoryName=sig_repo,
                    imageIds=image_ids
                )
                
                if response.get('failures'):
                    print("Failures:", response['failures'])
                
            print("Deletion complete.")
    else:
        print("No orphans to delete.")

if __name__ == "__main__":
    main()
