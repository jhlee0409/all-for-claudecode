# GraphQL Queries for Thread Resolution

## Fetch Review Threads

```graphql
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 1) {
            nodes { databaseId body author { login } path line }
          }
        }
      }
    }
  }
}
```

Usage:
```bash
gh api graphql -f query='...' -F owner='{owner}' -F repo='{repo}' -F pr={number}
```

## Resolve a Thread

```graphql
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { id isResolved }
  }
}
```

Usage:
```bash
gh api graphql -f threadId='{thread_id}' -f query='...'
```

## Notes

- REST API does NOT support thread resolution — GraphQL only
- Requires `repo` scope on the GitHub token
- Thread ID comes from the fetch query above (`nodes[].id`)
- Already-resolved threads (`isResolved: true`) should be skipped
