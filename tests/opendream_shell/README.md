# Unsupported shell compatibility

Run with BYOND 516.1681 and a verified Python executable:

```powershell
<python> tests/opendream_shell/run.py --byond-bin <bin> --output <evidence>
<python> tests/opendream_shell/run.py --byond-bin <bin> --output <tts-control> --negative-control tts
<python> tests/opendream_shell/run.py --byond-bin <bin> --output <dispatch-control> --negative-control dispatch
```

The fixture extracts actual production TTS and script dispatch bodies. It
substitutes counted shell/file/audio/control adapters and a listener-presence
flag, then executes both preprocessing branches without normal game startup.
Native TTS and script cooldown must remain intact. OpenDream must create no
speech IDs, shell calls or generated-audio lookups across 1000 requests; fixed
map requests still dispatch. Generated omission controls must fail explicitly.
No external program, audio file, production save or running server is used.
This does not prove OpenDream engine execution or whole-server memory savings.
