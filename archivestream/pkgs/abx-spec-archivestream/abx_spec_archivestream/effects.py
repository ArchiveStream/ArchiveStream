"""
Hookspec for side-effects that ArchiveStream plugins can trigger.

(e.g. network requests, binary execution, remote API calls, external library calls, etc.)
"""

__package__ = 'abx.archivestream'

import abx


@abx.hookspec
def check_remote_seed_connection(urls, extractor, credentials, created_by):
    pass


@abx.hookspec
def exec_extractor(url, extractor, credentials, config):
    pass

