# Testing Sesemi with Multipass

This guide shows how to test Sesemi scripts using [Multipass](https://canonical.com/multipass) VMs on macOS with snapshots for quick iteration.

## Prerequisites

Install Multipass on macOS:

```bash
brew install multipass
```

## Quick Start Testing Workflow

### 1. Create Ubuntu VM

```bash
# Create a fresh Ubuntu 24.04 VM
multipass launch --name sesemi-test --memory 4G --disk 30G --cpus 2 24.04

# Verify VM is running
multipass list
```

### 2. Initial Setup

```bash
# Access the VM
multipass shell sesemi-test

# Inside VM: Update and install git
sudo apt update
sudo apt install -y git

# Clone sesemi repository
git clone https://github.com/emreerkan/sesemi.git
cd sesemi

# Exit VM
exit
```

### 3. Create Snapshot (Clean State)

```bash
# Stop VM before taking snapshot
multipass stop sesemi-test

# Create snapshot of clean Ubuntu with sesemi repo
multipass snapshot sesemi-test --name clean-ubuntu

# Start VM again
multipass start sesemi-test
```

### 4. Test Sesemi

```bash
# Access VM
multipass shell sesemi-test

# Navigate to sesemi directory
cd sesemi

# Run setup
sudo ./setup.sh test.local

# Test the installation
# ...

# Exit when done
exit
```

### 5. Restore to Clean State

```bash
# Stop VM
multipass stop sesemi-test

# Restore to clean snapshot
multipass restore sesemi-test --snapshot clean-ubuntu

# Start VM
multipass start sesemi-test

# You can now test again immediately!
multipass shell sesemi-test
```

## Advanced Testing

### Multiple Snapshots

```bash
# Take snapshot at different stages
multipass stop sesemi-test
multipass snapshot sesemi-test --name after-packages
multipass start sesemi-test

# List all snapshots
multipass info sesemi-test

# Restore to specific snapshot
multipass stop sesemi-test
multipass restore sesemi-test --snapshot clean-ubuntu
multipass start sesemi-test
```

### Testing Migration Script

```bash
# 1. Create a VM with WordPress already installed
multipass shell sesemi-test
cd sesemi
sudo ./setup.sh source.local
exit

# 2. Take snapshot of "source server"
multipass stop sesemi-test
multipass snapshot sesemi-test --name source-server
multipass start sesemi-test

# 3. Prepare migration files
multipass shell sesemi-test
cd sesemi
sudo ./prepare-migration.sh
# Follow prompts to create migration tarball
exit

# 4. Transfer migration files to host
multipass transfer sesemi-test:~/migration-source.local.tar.gz ./

# 5. Create new "target" VM
multipass launch --name sesemi-target --memory 4G --disk 30G 24.04
multipass shell sesemi-target
sudo apt update && sudo apt install -y git
git clone https://github.com/emreerkan/sesemi.git
exit

# 6. Transfer migration files to target
multipass transfer migration-source.local.tar.gz sesemi-target:~/

# 7. Test migration
multipass shell sesemi-target
tar -xzf migration-source.local.tar.gz
cd sesemi
sudo ./migrate.sh source.local ~/migration-source.local
exit
```

### Accessing WordPress from macOS

```bash
# Get VM IP address
multipass info sesemi-test | grep IPv4

# Add to your /etc/hosts file
sudo nano /etc/hosts

# Add lines (replace with actual VM IP):
# 192.168.64.X test.local
# 192.168.64.X stage.test.local

# Now access from browser:
# https://test.local (production)
# https://stage.test.local (staging)
```

## VM Management

### Start/Stop

```bash
# Start VM
multipass start sesemi-test

# Stop VM
multipass stop sesemi-test

# Suspend VM (saves RAM state)
multipass suspend sesemi-test

# Check status
multipass list
```

### View VM Details

```bash
# Get detailed info
multipass info sesemi-test

# View snapshots
multipass info sesemi-test --snapshots
```

### Delete Snapshots

```bash
# Delete specific snapshot
multipass snapshot sesemi-test --name clean-ubuntu --delete

# Delete all snapshots
multipass snapshot sesemi-test --delete --all
```

### Delete VM

```bash
# Delete VM (keeps it in trash)
multipass delete sesemi-test

# Permanently remove deleted VMs
multipass purge

# Or delete and purge in one command
multipass delete --purge sesemi-test
```

## Troubleshooting

### VM Won't Start

```bash
# Check VM status and errors
multipass list
multipass info sesemi-test

# Try restarting multipass service
sudo launchctl stop com.canonical.multipassd
sudo launchctl start com.canonical.multipassd
```

### Out of Disk Space

```bash
# Check disk usage inside VM
multipass shell sesemi-test
df -h
exit

# Create new VM with more space
multipass launch --name sesemi-large --disk 50G 24.04
```

### Network Issues

```bash
# Restart VM networking
multipass restart sesemi-test

# Get new IP if needed
multipass info sesemi-test | grep IPv4
```

## Tips for Efficient Testing

1. **Always snapshot before testing** - Create snapshot right after initial Ubuntu setup
2. **Keep multiple VMs** - One for setup testing, one for migration testing
3. **Name snapshots clearly** - `clean-ubuntu`, `after-lamp`, `full-wordpress`, etc.
4. **Monitor resources** - Use `multipass info` to check CPU/memory usage
5. **Auto-start disabled** - VMs don't auto-start on macOS reboot (good for testing)

## Common Testing Scenarios

### Test Resume Functionality

```bash
multipass shell sesemi-test
cd sesemi
sudo ./setup.sh test.local
# Press Ctrl+C to interrupt during installation
sudo ./setup.sh test.local --continue
# Should resume from last successful step
```

### Test Cleanup

```bash
multipass shell sesemi-test
cd sesemi
sudo ./setup.sh test.local
# After installation completes
sudo ./setup.sh test.local --cleanup
# Verify all traces removed
```

### Test Restart

```bash
multipass shell sesemi-test
cd sesemi
sudo ./setup.sh test.local
# After installation completes
sudo ./setup.sh test.local --restart
# Should clean up and reinstall
```

## Performance Notes

- **Snapshot creation**: ~5-10 seconds
- **Snapshot restore**: ~3-5 seconds
- **VM start**: ~10-15 seconds
- **Full sesemi install**: ~5-10 minutes (depending on network)

Much faster than reinstalling Ubuntu each time!

---

## Note on Other Platforms

This guide is written for **macOS**, but Multipass also works on **Linux** and **Windows**. Most commands are identical across platforms, with minor differences in installation and service management.

For platform-specific instructions, please refer to the [official Multipass documentation](https://documentation.ubuntu.com/multipass/latest/).
