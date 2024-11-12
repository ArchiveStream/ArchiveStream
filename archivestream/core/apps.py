__package__ = 'archivestream.core'

from django.apps import AppConfig

import archivestream


class CoreConfig(AppConfig):
    name = 'core'

    def ready(self):
        """Register the archivestream.core.admin_site as the main django admin site"""
        from django.conf import settings
        archivestream.pm.hook.ready(settings=settings)
        
        from core.admin_site import register_admin_site
        register_admin_site()
        


