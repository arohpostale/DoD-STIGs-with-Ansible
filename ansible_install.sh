#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Initialize an array to collect errors
errors=()

# Step 1: Enable the EPEL repository
echo "Enabling the EPEL repository..."
if ! yum install -y epel-release; then
    errors+=("Failed to enable the EPEL repository.")
fi

# Step 2: Update the package index
echo "Updating the package index..."
if ! yum update -y; then
    errors+=("Failed to update the package index.")
fi

# Step 3: Install required packages
echo "Installing required packages..."
if ! yum install -y python3 python3-pip curl git openssh-server; then
    errors+=("Failed to install required packages.")
fi

# Step 4: Set Python 3 as the default python
echo "Setting Python 3 as the default Python version..."
if ! alternatives --set python /usr/bin/python3; then
    errors+=("Failed to set Python 3 as the default Python version.")
fi

# Step 5: Update CA certificates
echo "Updating CA certificates..."
if ! yum install -y ca-certificates || ! update-ca-trust force-enable; then
    errors+=("Failed to update CA certificates.")
fi

# Step 6: Upgrade pip to the latest version
echo "Upgrading pip to the latest version..."
if ! pip3 install --upgrade pip --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org; then
    errors+=("Failed to upgrade pip to the latest version.")
fi

# Step 7: Install setuptools_rust
echo "Installing setuptools_rust..."
if ! pip3 install setuptools-rust --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org; then
    errors+=("Failed to install setuptools-rust.")
fi

# Step 8: Install Ansible from EPEL repository
echo "Installing Ansible..."
if ! yum install -y ansible; then
    errors+=("Failed to install Ansible.")
fi

# Step 9: Install additional Python packages required by Ansible using pip3
echo "Installing additional Python packages using pip3..."
if ! pip3 install paramiko argcomplete passlib jmespath --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org; then
    errors+=("Failed to install additional Python packages.")
fi

# Step 10: Activate global Python argcomplete
echo "Activating global Python argcomplete..."
if ! activate-global-python-argcomplete; then
    errors+=("Failed to activate global Python argcomplete.")
fi

# Step 11: Create directories for Ansible configuration
echo "Creating directories for Ansible configuration..."
mkdir -p /etc/ansible /etc/ansible/roles /var/log/ansible
touch /etc/ansible/ansible.cfg

# Step 12: Setup basic ansible.cfg
echo "[defaults]" > /etc/ansible/ansible.cfg
echo "inventory = /etc/ansible/hosts" >> /etc/ansible/ansible.cfg
echo "roles_path = /etc/ansible/roles" >> /etc/ansible/ansible.cfg
echo "log_path = /var/log/ansible/ansible.log" >> /etc/ansible/ansible.cfg

# Step 13: Generate SSH keys for Ansible
echo "Generating SSH keys for Ansible..."
if ! ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/ansible_key; then
    errors+=("Failed to generate SSH keys for Ansible.")
fi

# Step 14: Add localhost to Ansible inventory
echo "Adding localhost to Ansible inventory..."
if ! echo "localhost ansible_connection=local" | sudo tee /etc/ansible/hosts; then
    errors+=("Failed to add localhost to Ansible inventory.")
fi

# Step 15: Verify Python installation
echo "Verifying Python installation..."
if ! python3 --version; then
    errors+=("Python installation verification failed.")
fi

# Step 16: Verify pip installation
echo "Verifying pip installation..."
if ! pip3 --version; then
    errors+=("pip installation verification failed.")
fi

# Step 17: Verify required Python packages installation
echo "Verifying required Python packages installation..."
for package in paramiko argcomplete passlib jmespath setuptools-rust; do
    if ! pip3 show $package > /dev/null 2>&1; then
        errors+=("Package $package is not installed.")
    fi
done

# Step 18: Verify Ansible installation
echo "Verifying Ansible installation..."
if ! ansible --version; then
    errors+=("Ansible installation verification failed.")
fi

# Step 19: Run a simple Ansible ping test
echo "Running a simple Ansible ping test..."
if ! ansible all -m ping; then
    errors+=("Ansible ping test failed.")
fi

# Report any errors
if [ ${#errors[@]} -eq 0 ]; then
    echo "Ansible setup and verification completed successfully."
else
    echo "The following errors were encountered during setup and verification:"
    for error in "${errors[@]}"; do
        echo "- $error"
    done
fi
