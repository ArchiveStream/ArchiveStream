import sys
import click
from rich import print
from archivestream.config.django import setup_django

setup_django()


def parse_stdin_to_args(io=sys.stdin):
    for line in io.read().split('\n'):
        for url_or_id in line.split(' '):
            if url_or_id.strip():
                yield url_or_id.strip()


# Gather data from stdin in case using a pipe
if not sys.stdin.isatty():
    sys.argv += parse_stdin_to_args(sys.stdin)


@click.command()
@click.argument("snapshot_ids_or_urls", type=str, nargs=-1)
def extract(snapshot_ids_or_urls):
    for url_or_snapshot_id in snapshot_ids_or_urls:
        print('- EXTRACTING', url_or_snapshot_id, file=sys.stderr)
        for result in archivestream.pm.hook.extract(url_or_snapshot_id):
            print(result)

if __name__ == "__main__":
    extract()
