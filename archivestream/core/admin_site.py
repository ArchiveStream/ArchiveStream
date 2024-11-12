__package__ = 'archivestream.core'

from django.contrib import admin

import archivestream

class ArchiveStreamAdmin(admin.AdminSite):
    site_header = 'ArchiveStream'
    index_title = 'Admin Views'
    site_title = 'Admin'
    namespace = 'admin'


archivestream_admin = ArchiveStreamAdmin()
archivestream_admin.disable_action('delete_selected')
# TODO: https://stackoverflow.com/questions/40760880/add-custom-button-to-django-admin-panel



# patch admin with methods to add data views (implemented by admin_data_views package)
# https://github.com/MrThearMan/django-admin-data-views
# https://mrthearman.github.io/django-admin-data-views/setup/
from admin_data_views.admin import get_app_list, admin_data_index_view, get_admin_data_urls, get_urls
archivestream_admin.get_app_list = get_app_list.__get__(archivestream_admin, ArchiveStreamAdmin)
archivestream_admin.admin_data_index_view = admin_data_index_view.__get__(archivestream_admin, ArchiveStreamAdmin)       # type: ignore
archivestream_admin.get_admin_data_urls = get_admin_data_urls.__get__(archivestream_admin, ArchiveStreamAdmin)           # type: ignore
archivestream_admin.get_urls = get_urls(archivestream_admin.get_urls).__get__(archivestream_admin, ArchiveStreamAdmin)
############### Admin Data View sections are defined in settings.ADMIN_DATA_VIEWS #########


def register_admin_site():
    """Replace the default admin site with our custom ArchiveStream admin site."""
    from django.contrib import admin
    from django.contrib.admin import sites

    admin.site = archivestream_admin
    sites.site = archivestream_admin
    
    # register all plugins admin classes
    archivestream.pm.hook.register_admin(admin_site=archivestream_admin)
    
    return archivestream_admin
