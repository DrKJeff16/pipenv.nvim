# -*- coding: utf-8 -*-
"""Python component for ``MyPlugin``."""
from typing import NoReturn

import pynvim


@pynvim.plugin
class MyPlugin:
    """
    MyPlugin object.

    Parameters
    ----------
    nvim : pynvim.Nvim
        The ``Nvim`` object instance.

    Attributes
    ----------
    nvim : pynvim.Nvim
        The ``Nvim`` object instance.
    """

    nvim: pynvim.nvim

    def __init__(self, nvim: pynvim.Nvim):
        self.nvim = nvim

    @pynvim.command("MyPluginFoo", nargs=0)
    def foo(self) -> NoReturn:
        """Executes the ``MyPluginFoo`` command."""
        self.nvim.out_write("Whatever\n")

# vim: set ts=4 sts=4 sw=4 et ai si sta:
