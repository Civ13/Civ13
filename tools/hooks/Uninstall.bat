@set PYTHONPATH=%~dp0..
@py -3 -m hooks.install --uninstall %*
@pause
