from functools import wraps
from time import time

def timed_function(func):
    """
    Very simple profiling decorator for debugging.
    Usage:
        @timed_function
        def my_func():
            ...
    
    More advanced alternatives:
        - viztracer ../.venv/bin/archivestream manage check          # https://viztracer.readthedocs.io/en/latest/filter.html
        - python -m cProfile -o archivestream.prof ../.venv/bin/archivestream manage check; snakeviz archivestream.prof
        - Django Debug Toolbar + django-debug-toolbar-flamegraph
        + Django Requests Tracker (requests-tracker)
    """
    @wraps(func)
    def wrap(*args, **kwargs):
        if args and hasattr(args[0], '__module__'):
            module = args[0].__module__
        else:
            module = func.__module__
        ts_start = time()
        result = func(*args, **kwargs)
        ts_end = time()
        ms_elapsed = int((ts_end-ts_start) * 1000)
        print(f'[DEBUG][{ms_elapsed}ms] {module}.{func.__name__}(...)')
        return result
    return wrap
