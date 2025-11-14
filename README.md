# MESH



## Getting Started

To run the first steps without SSH key:

    $ sudo apt install sshpass


### Check

    $ ansible-playbook -k -i pis.ini ping.yml

### Copy ssh key

    $ ansible-playbook -k -i pis.ini copy_ssh_key.yml -e "key=PATH_TO_PUBLIC_KEY"


After this, all playbooks can be run without the -k flag - and without password prompt.

## Customize


## Install Software

    
    $ ansible-playbook -i pis.ini install_supercollider.yml


Processing: needs to be from tarball (github releases) NOT from snap - that one is missing the processing-java