# TP-Link Configuration

The `tplink` model is used for TP-Link JetStream managed switches and the
DeltaStream GPON OLT. The notes below apply to all of them.

## SSH authentication: avoid public-key authentication

Some TP-Link devices (the DeltaStream GPON OLT for example) **abort the SSH
connection if the client attempts public-key authentication before the
password**. By default net-ssh offers any key from the SSH agent or the default
identity files first, so when the Oxidized host has SSH keys the device closes the
connection before the password is ever tried:

```text
connection closed by remote host (Net::SSH::Disconnect)
```

This is why the same device may connect fine from one host (no SSH keys) and fail
from another (keys present). Tell Oxidized to skip `publickey` with the
`auth_methods` variable (see [SSH Auth Methods](../Inputs.md#ssh-auth-methods)).
It can be set globally, by group, by model or by node, e.g. for every `tplink`
device:

```yaml
models:
  tplink:
    vars:
      auth_methods: ["none", "password"]
```

### Capturing a simulation with device2yaml.rb

`extra/device2yaml.rb` has no `auth_methods` option, but net-ssh reads
`~/.ssh/config`, so add a host block for the device to force password
authentication:

```text
Host <device-ip>
    PreferredAuthentications password
    PubkeyAuthentication no
```

This CLI also submits a command only on a carriage return, so run device2yaml with
`-n '\r\n'`; otherwise the commands are echoed but never executed.

## Enable mode

The model enters privileged (enable) mode on login. TP-Link devices enable with no
password by default (JetStream switches and the DeltaStream OLT go straight to the
`#` prompt), and no password is sent unless the device prompts for one. If your
device has an enable password, set it with the `enable` variable.

Back to [Model-Notes](README.md)
