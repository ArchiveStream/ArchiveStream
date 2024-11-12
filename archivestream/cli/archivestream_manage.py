#!/usr/bin/env python3

__package__ = 'archivestream.cli'
__command__ = 'archivestream manage'

import sys
from pathlib import Path
from typing import Optional, List, IO

from archivestream.misc.util import docstring
from archivestream.config import DATA_DIR
from ..main import manage


@docstring(manage.__doc__)
def main(args: Optional[List[str]]=None, stdin: Optional[IO]=None, pwd: Optional[str]=None) -> None:
    manage(
        args=args,
        out_dir=Path(pwd) if pwd else DATA_DIR,
    )


if __name__ == '__main__':
    main(args=sys.argv[1:], stdin=sys.stdin)
