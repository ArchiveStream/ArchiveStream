__package__ = 'archivestream.core'

import abx

@abx.hookimpl
def register_admin(admin_site):
    """Register the core.models views (Snapshot, ArchiveResult, Tag, etc.) with the admin site"""
    from core.admin import register_admin
    register_admin(admin_site)



@abx.hookimpl
def get_CONFIG():
    from archivestream.config.common import (
        SHELL_CONFIG,
        STORAGE_CONFIG,
        GENERAL_CONFIG,
        SERVER_CONFIG,
        ARCHIVING_CONFIG,
        SEARCH_BACKEND_CONFIG,
    )
    return {
        'SHELL_CONFIG': SHELL_CONFIG,
        'STORAGE_CONFIG': STORAGE_CONFIG,
        'GENERAL_CONFIG': GENERAL_CONFIG,
        'SERVER_CONFIG': SERVER_CONFIG,
        'ARCHIVING_CONFIG': ARCHIVING_CONFIG,
        'SEARCHBACKEND_CONFIG': SEARCH_BACKEND_CONFIG,
    }

