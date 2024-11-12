__package__ = 'abx.archivestream'

import importlib
from typing import Dict, Set, Any, TYPE_CHECKING

from benedict import benedict

from django.conf import settings

import abx


@abx.hookimpl
def get_or_create_snapshot(crawl, url, config):
    pass

@abx.hookimpl
def update_crawl_schedule_next_run_at(crawl_schedule, next_run_at):
    pass

@abx.hookimpl
def create_crawl_copy(crawl_to_copy, schedule):
    pass

@abx.hookimpl
def create_crawl(seed, depth, tags_str, persona, created_by, config, schedule):
    pass




def create_crawl_from_ui_action(urls, extractor, credentials, depth, tags_str, persona, created_by, crawl_config):
    if seed_is_remote(urls, extractor, credentials):
        # user's seed is a remote source that will provide the urls (e.g. RSS feed URL, Pocket API, etc.)
        uri, extractor, credentials = abx.archivestream.effects.check_remote_seed_connection(urls, extractor, credentials, created_by)
    else:
        # user's seed is some raw text they provided to parse for urls, save it to a file then load the file as a Seed
        uri = abx.archivestream.writes.write_raw_urls_to_local_file(urls, extractor, tags_str, created_by)  # file:///data/sources/some_import.txt
    
    seed = abx.archivestream.writes.get_or_create_seed(uri=remote_uri, extractor, credentials, created_by)
    # abx.archivestream.events.on_seed_created(seed)
        
    crawl = abx.archivestream.writes.create_crawl(seed=seed, depth=depth, tags_str=tags_str, persona=persona, created_by=created_by, config=crawl_config, schedule=None)
    abx.archivestream.events.on_crawl_created(crawl)


@abx.hookimpl(specname='on_crawl_schedule_tick')
def create_crawl_from_crawlschedule_if_due(crawl_schedule):
    # make sure it's not too early to run this scheduled import (makes this function indepmpotent / safe to call multiple times / every second)
    if timezone.now() < crawl_schedule.next_run_at:
        # it's not time to run it yet, wait for the next tick
        return
    else:
        # we're going to run it now, bump the next run time so that no one else runs it at the same time as us
        abx.archivestream.writes.update_crawl_schedule_next_run_at(crawl_schedule, next_run_at=crawl_schedule.next_run_at + crawl_schedule.interval)
    
    crawl_to_copy = None
    try:
        crawl_to_copy = crawl_schedule.crawl_set.first()  # alternatively use .last() to copy most recent crawl instead of very first crawl
    except Crawl.DoesNotExist:
        # there is no template crawl to base the next one off of
        # user must add at least one crawl to a schedule that serves as the template for all future repeated crawls
        return
    
    new_crawl = abx.archivestream.writes.create_crawl_copy(crawl_to_copy=crawl_to_copy, schedule=crawl_schedule)
    abx.archivestream.events.on_crawl_created(new_crawl)


@abx.hookimpl(specname='on_crawl_post_save')
def create_root_snapshot_from_seed(crawl):
    # create a snapshot for the seed URI which kicks off the crawl
    # only a single extractor will run on it, which will produce outlinks which get added back to the crawl
    root_snapshot, created = abx.archivestream.writes.get_or_create_snapshot(crawl=crawl, url=crawl.seed.uri, config={
        'extractors': (
            abx.archivestream.reads.get_extractors_that_produce_outlinks()
            if crawl.seed.extractor == 'auto' else
            [crawl.seed.extractor]
        ),
        **crawl.seed.config,
    })
    if created:
        abx.archivestream.events.on_snapshot_created(root_snapshot)
        abx.archivestream.writes.update_crawl_stats(started_at=timezone.now())


@abx.hookimpl(specname='on_snapshot_created')
def create_archiveresults_pending_from_snapshot(snapshot, config):
    config = get_scope_config(
        # defaults=settings.CONFIG_FROM_DEFAULTS,
        # collection=settings.CONFIG_FROM_FILE,
        # environment=settings.CONFIG_FROM_ENVIRONMENT,
        persona=archiveresult.snapshot.crawl.persona,
        seed=archiveresult.snapshot.crawl.seed,
        crawl=archiveresult.snapshot.crawl,
        snapshot=archiveresult.snapshot,
        archiveresult=archiveresult,
        # extra_config=extra_config,
    )
    
    extractors = abx.archivestream.reads.get_extractors_for_snapshot(snapshot, config)
    for extractor in extractors:
        archiveresult, created = abx.archivestream.writes.get_or_create_archiveresult_pending(
            snapshot=snapshot,
            extractor=extractor,
            status='pending'
        )
        if created:
            abx.archivestream.events.on_archiveresult_created(archiveresult)



@abx.hookimpl(specname='on_archiveresult_updated')
def create_snapshots_pending_from_archiveresult_outlinks(archiveresult):
    config = get_scope_config(...)
    
    # check if extractor has finished succesfully, if not, dont bother checking for outlinks
    if not archiveresult.status == 'succeeded':
        return
    
    # check if we have already reached the maximum recursion depth
    hops_to_here = abx.archivestream.reads.get_outlink_parents(crawl_pk=archiveresult.snapshot.crawl_id, url=archiveresult.url, config=config)
    if len(hops_to_here) >= archiveresult.crawl.max_depth +1:
        return
    
    # parse the output to get outlink url_entries
    discovered_urls = abx.archivestream.reads.get_archiveresult_discovered_url_entries(archiveresult, config=config)
    
    for url_entry in discovered_urls:
        abx.archivestream.writes.create_outlink_record(src=archiveresult.snapshot.url, dst=url_entry.url, via=archiveresult)
        abx.archivestream.writes.create_snapshot(crawl=archiveresult.snapshot.crawl, url_entry=url_entry)
        
    # abx.archivestream.events.on_crawl_updated(archiveresult.snapshot.crawl)
