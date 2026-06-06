# Scry

<!-- DOCS HERE -->

Scry is the version control system used in many {du}punkto projects,
most notably being the primary version control system used in
[Vik](https://docs.dupunkto.org/vik) (which is not a {du}punkto project, oops).

## Architecture

Scry is a thin wrapper around `git`, but uses different concepts:

- An **object**, which is a file that is versioned.
- An **edit**, which is a change to an object.
- A **revision**, which is combines multiple edits into a single change record.

Changes to objects are tracked by calling `track/2` with the current state
of the object. If this state is different from the previous state known by
Scry, a new edit will be created.

Changes are tracked in a single monolithic git repository, where each Scry object
is represented as a file in the root folder. Every edit or revision in Scry is
analogous to one commit in git. Each git commit thus only modifies a single file.

Scry is designed to 'fire-and-forget'. An example use-case would be a text editor
that sends its contents over the wirte on every save, or on a debounce. This naturally
results in many small edits to an object, which are internally represented as commits
titled `(edit) object` (incremental commits). At the end of an edit session, `squash/2`
can be called to squash all pending edits into a revision, which is internally
represented by squashing the relevant commits into a single commit titled
`(revision) object <message>` (squashed commits).

## Deployment

Configure the following environment variables:

- `ROOT`: the path to the internal git repository. Make sure the path is
  pointing to a writable non-bare repo that has already been initialized.
  Scry does not auto-initialize non-existant repos.

- `TOKEN`: the token to be passed as `Authorization` header for API calls,
  or as path segment in webhook requests. Preferably cryptographically secure.

A prebuilt docker image is available at
[ghcr.io/dupunkto/scry](https://github.com/dupunkto/scry/pkgs/container/scry).