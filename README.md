# SUSE Cloud Foundry

SUSE Cloud Foundry (SCF) is a [Cloud Foundry](https://www.cloudfoundry.org)
distribution based on the open source version but with several very key
differences:

* Uses [fissile](https://github.com/suse/fissile) to containerize the CF components, for running on top of Kubernetes (and Docker)
* CF Components run on an OpenSUSE Stemcell
* CF Apps optionally can run on a preview of the OpenSUSE Stack (rootfs + buildpacks)

# Disclaimer

Fissile has been around for a few years now and its containerization technology
is fairly stable; however deploying directly to kubernetes is relatively new, as is the
OpenSUSE stack and stemcell. This means that things are liable to break as we continue
development. Specifically links and where things are hosted are still in flux and will most
likely break.

For development testing we've mainly been targeting the following so they should
be a known working quantity:

| OS             | Virtualization |
|----------------|----------------|
| OpenSUSE 42.x  | Libvirt        |
| Mac OSX Sierra | VirtualBox     |

For more production-like deploys we've been targetting baremetal Kubernetes 1.6.1 (using only 1.5 features)
though these deploys currently require the adventurer to be able to debug and problem solve
which takes knowledge of the components this repo brings together currently.

Table of Contents
=================

   * [SUSE Cloud Foundry](#suse-cloud-foundry)
   * [Disclaimer](#disclaimer)
   * [Table of Contents](#table-of-contents)
   * [Deploying SCF on Vagrant](#deploying-scf-on-vagrant)
      * [Requirements](#requirements)
      * [Deploying](#deploying)
      * [Usage](#usage)
      * [Troubleshooting](#troubleshooting)
   * [Deploying SCF on Kubernetes](#deploying-scf-on-kubernetes)
      * [Makefile targets](#makefile-targets)
         * [Vagrant VM Targets](#vagrant-vm-targets)
   * [Development FAQ](#development-faq)
      * [Where do I find logs?](#where-do-i-find-logs)
      * [How do I clear all data and begin anew without rebuilding everything?](#how-do-i-clear-all-data-and-begin-anew-without-rebuilding-everything)
      * [How do I run smoke and acceptance tests?](#how-do-i-run-smoke-and-acceptance-tests)
         * [How do I run a subset of SCF acceptance tests?](#how-do-i-run-a-subset-of-scf-acceptance-tests)
         * [How do I run a subset of Cloud Foundry acceptance tests?](#how-do-i-run-a-subset-of-cloud-foundry-acceptance-tests)
      * [fissile refuses to create images that already exist. How do I recreate images?](#fissile-refuses-to-create-images-that-already-exist-how-do-i-recreate-images)
      * [My vagrant box is frozen. What can I do?](#my-vagrant-box-is-frozen-what-can-i-do)
      * [Can I target the cluster from the host using the cf CLI?](#can-i-target-the-cluster-from-the-host-using-the-cf-cli)
      * [How do I connect to the Cloud Foundry database?](#how-do-i-connect-to-the-cloud-foundry-database)
      * [How do I add a new BOSH release to SCF?](#how-do-i-add-a-new-bosh-release-to-scf)
      * [What does my dev cycle look like when I work on Component X?](#what-does-my-dev-cycle-look-like-when-i-work-on-component-x)
      * [How do I expose new settings via environment variables?](#how-do-i-expose-new-settings-via-environment-variables)
      * [How do I bump the submodules for the various releases?](#how-do-i-bump-the-submodules-for-the-various-releases)
      * [Can I suspend or resume my vagrant VM?](#can-i-suspend-or-resume-my-vagrant-vm)
      * [How do I develop an upstream PR?](#how-do-i-develop-an-upstream-pr)
      * [How do I publish SCF and BOSH images?](#how-do-i-publish-scf-and-bosh-images)
      * [How do I generate certs for pre-built Docker images?](#how-do-i-generate-certs-for-prebuilt-docker-images)
      * [How do I use an authenticated registry for my Docker images?](#how-do-i-use-an-authenticated-registry-for-my-docker-images)
      * [Using Persi NFS](#using-persi-nfs)

# Deploying SCF on Vagrant

## Requirements

1. We recommend running on a machine with more than 16G of ram _for now_.
1. You must install vagrant (1.9.5+): [https://www.vagrantup.com](https://www.vagrantup.com)
1. Install the following vagrant plugins

    * vagrant-reload
      ```bash
      vagrant plugin install vagrant-reload
      ```
    * vagrant-libvirt (if using libvirt)
      ```bash
      vagrant plugin install vagrant-libvirt
      ```

## Deploying

Deploying on vagrant is highly scripted and so there should be very little to do to get
a working system.

1. Initial repo check out

    ```bash
    git clone --recurse-submodules https://github.com/SUSE/scf
    ```

2. Building the system

    ```bash
    # Bring the vagrant box up
    vagrant up --provider X # Where X is libvirt | virtualbox. See next section for additional options.

    # Once the vagrant box is up, ssh into it
    vagrant ssh

    # The scf directory you cloned has been mounted into the guest OS, cd into it
    cd scf

    # This runs a combination of bosh & fissile in order to create the docker
    # images and helm charts you'll need. Once this step is done you can see
    # images available via "docker images"
    make vagrant-prep
    # This is the final step, where it will install the uaa helm chart into the 'uaa' namespace
    # and the scf helm chart into the 'cf' namespace.
    make run

    # Watch the status of the pods, when everything is fully ready it should be usable.
    pod-status --watch

    # Currently the api role takes a very long time to do its migrations (~20 mins), to see if it's
    # doing migrations check the logs, if you see messages about migrations please be patient, otherwise
    # see the Troubleshooting guide.
    k logs -f cf:^api-[0-9]
    ```
3. Changing the default STEMCELL and STACK

   The default stemcell and stack are set to OpenSUSE. The versions are defined
   in `bin/common/versions.sh`.

   To build with the SLE stemcell and stack, the environment variable
   `USE_SLE_BASE` must be set to `true` before you enter the `scf` directory.
   This allows direnv to configure the various stemcell and stack env vars. The
   `FISSILE_DOCKER_REPOSITORY` env var will need to be set, and Docker configured
   to login to the repository.

   After changing the stemcell you have to remove the contents of
   `~vagrant/.fissile/compilation` and `~vagrant/scf/.fissile/compilation` inside
   the vagrant box. Afterwards recompile scf (for details see section "2. Building
   the system").

   **Example:**

   ```
   $ cd ~
   $ export USE_SLE_BASE=true
   $ export FISSILE_DOCKER_REPOSITORY=registry.example.com
   $ docker login ${FISSILE_DOCKER_REPOSITORY} -u username -p password
   $ cd scf
   ```

3. Environment variables to configure `vagrant up` (optional)
    - `VAGRANT_VBOX_BRIDGE`: Set this to the name of an interface to enable bridged networking when
      using the Virtualbox provider. Turning on bridged networking will allow your vagrant box to receive
      an IP accessible anywhere on the network. While Virtualbox is able to bridge over an interface
      without any special networking configuration (and may even do this on OSX), bridged networking may
      not be supported when the provided interface is a wireless interface.See the [Virtualbox docs](
      https://www.virtualbox.org/manual/ch06.html#network_bridged) on bridged networking for more
      information.
    - `VAGRANT_KVM_BRIDGE`: Set this to the name of your host's linux bridge interface if you have one
      configured. If using Wicked as your network manager, you can configure one by setting the config
      files for your default interface and bridge interface as follows:
      ```
      #default interface:
      BOOTPROTO='none'
      STARTMODE='auto'
      DHCLIENT_SET_DEFAULT_ROUTE='yes'
      ```
      ```
      #bridged interface:
      DHCCLIENT_SET_DEFAULT_ROUTE='yes'
      STARTMODE='auto'
      BOOTPROTO='dhcp'
      BRIDGE='yes'
      BRIDGE_STP='off'
      BRIDGE_FORWARDDELAY='0'
      BRIDGE_PORTS='eth0'
      BRIDGE_PORTPRIORITIES='-'
      BRIDGE_PATHCOSTS='-'
      ```
      For example, if your default interface is named `eth0`', you would edit
      `/etc/sysconfig/network/ifcfg-eth0` and `/etc/sysconfig/network/ifcfg-br0`
      with the above settings. Then, after the desired configuration is in place, run
      `wicked ifreload all` and wait for wicked to apply the changes.
    - `VAGRANT_DHCP`: Set this to any value when using virtual networking (as opposed to bridged networking)
      in order to let your VM receive an IP via DHCP in the virtual network. If this environment variable is
      unset, the VM will instead obtain the IP 192.168.77.77.


**Note:** If every role does not go green in `pod-status --watch` refer to [Troubleshooting](#troubleshooting)

3. Pulling updates

    When you want to pull the latest changes from the upstream you should:

    ```
    # Pull the changes (or checkout the commit you want):
    git pull

    # Update all submodules to match the checked out commit
    git submodule update --init --recursive
    ```

    Sometimes, when we bump the BOSH release submodules, they move to a different
    location and you need to run:

    ```
      git submodule sync --recursive
    ```

    You might have to run the `git submodule update --init --recursive` again after the
    last command.

    If there are untracked changes from submodule directories you can safely remove them.

    E.g. A command that will update all submodules and drop any changed or untracked files in them is:

    ```
      git submodule update --recursive --force && git submodule foreach --recursive 'git checkout . && git clean -fdx'
    ```

    **Make sure you understand what the [`git clean` flags mean](https://git-scm.com/docs/git-clean/) before you run this**

    Now you need to rebuild the images inside the vagrant box:

    ```
    make stop # And wait until all pods are stopped and removed
    make vagrant-prep kube run
    ```

## Usage

The vagrant box is set up with default certs, passwords, ips, etc. to make it easier
to run and develop on. So to access it and try it out all you should need is to get the
CF client and connect to it. Once you've connected with the CF cli you should be able to
do anything you can do with a vanilla Cloud Foundry.

You can get the the cf client here:
[github.com/cloudfoundry/cli](https://github.com/cloudfoundry/cli#downloads)

The way the vagrant box is created is by making a network with a static IP on the host.
This means that you cannot connect to it from some other box.

```bash
# Attach to the endpoint (self-signed certs in dev mode requires skipping validation)
# cf-dev.io simply resolves to the static IP 192.168.77.77 that vagrant provisions
# This DNS resolution may fail on certain DNS providers that block resolution to 192.168.*
# Unless you've changed the default credentials in the configuration it's admin/changeme
cf api --skip-ssl-validation https://api.cf-dev.io
cf login -u admin -p changeme
```

## Troubleshooting

Typically Vagrant box deployments encounter one of few problems:

* uaa does not come up correctly (constantly not ready in pod-status)

    In this case perform the following

    ```bash
    # Delete everything in the uaa namespace
    k delete namespace uaa

    # Delete the pv related to uaa/mysql-data-mysql-0
    k get pv # Find it
    k delete pv pvc-63aab845-4fe7-11e7-9c8d-525400652dd8

    make uaa-run
    ```

* api does not come up correctly and is not performing migrations (curl output in logs)

    uaa is not functioning, try steps above

* vagrant under VirtualBox freezing for no obvious reason: try enabling the "Use Host I/O Cache" option in `Settings->Storage->SATA Controller`.

* volumes don't get mounted when suspending/resuming the box

  For now only `vagrant stop` and then `vagrant up` fixes it.

* When restarting the box with either `vagrant reload` or `vagrant stop/up` some
  pods never come up automatically. You have to do a `make stop` and then
  `make run` to bring this up.

* Pulling images during any of `vagrant up` or `make vagrant-prep` or `make docker-deps`
  fails.

  In order to have access to the internet inside the vagrant box and inside the
  containers (withing the box) you need to enable ip forwarding for both the host
  and the vagrant box (which is the host for containers)

  To enable temporarily:

  ```echo "1" | sudo tee /proc/sys/net/ipv4/ip_forward```

  or to do this permanently:

  ```echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/50-docker-ipv4-ipforward.conf```

  and restart your docker service (or run `vagrant up` again if changed on the host)

# Deploying SCF on Kubernetes

After careful consideration of the difficulty of the current install, we decided not
to detail the instructions to install on bare K8s because it still requires far too
much knowledge of SCF related systems and troubleshooting.

Please be patient while we work on a set of [Helm](https://github.com/kubernetes/helm)
charts that will help people easily install on any Kubernetes.

## Makefile targets

### Vagrant VM Targets

Name            | Effect |
--------------- | ---- |
`run`            | Set up SCF on the current node |
`stop`            | Stop SCF on the current node |
`vagrant-box`    | Build the Vagrant box image using `packer` |
`vagrant-prep`    | Shortcut for building everything needed for `make run` |

# Development FAQ

### Where do I find logs?

There are two places to see logs. Monit's logs, and the actual log files of each process in the
container.

1. Monit logs

    ```bash
    # Normal form using kubectl
    kubectl logs --namespace cf router-3450916350-xb3kf
    # Short form using k
    k logs cf:^router-[0-9]
    ```

1. Container process logs

    ```bash
    # Normal form
    kubectl exec -it --namespace cf nats-0 -- env LINES=$LINES COLS=$COLS TERM=$TERM bash
    # Short form
    k ssh :nats

    # After ssh'ing, the logs are all in this directory for each process:
    cd /var/vcap/sys/log
    ```

### How do I clear all data and begin anew without rebuilding everything?

On the Vagrant box, run the following commands:

```bash
make stop
make run
```

### How do I run smoke and acceptance tests?

On the Vagrant box, when `pod-status` reports all roles are running, enable `diego_docker` support with

```bash
cf enable-feature-flag diego_docker
```

and execute the following commands:

```bash
make smoke
make cats
make brain
```

#### How do I run a subset of SCF acceptance tests?

Deploy `acceptance-tests-brain` as above, but first modify the environment to include `INCLUDE=pattern` or
`EXCLUDE=pattern`.    For example to run just `005_sso_test.sh` and `014_sso_authenticated_passthrough_test.sh`, you
could add `INCLUDE` with a value of `sso`.

It is also possible to run custom tests by mounting them at the `/tests` mountpoint inside the container.    The
mounted tests will be combined with the bundled tests. However, to do so you will need to manually run it via docker.
To exclude the bundled tests match against names starting with 3 digits followed by an underscore (as in,
`EXCLUDE=\b\d{3}_`) or explicitly select only the mounted tests with `INCLUDE=^/tests/`.

#### How do I run a subset of Cloud Foundry acceptance tests?

Deploy `acceptance-tests` after modifying the environment block to include `CATS_SUITES=-suite,+suite`.    Each suite is
separated by a comma.    The modifiers apply until the next modifier is seen, and have the following meanings:

Modifier | Meaning
--- | ---
`+` | Enable the following suites
`-` | Disable the following suites
`=` | Disable all suites, and enable the following suites

### `fissile` refuses to create images that already exist. How do I recreate images?

On the Vagrant box, run the following commands:

```bash
cd ~/scf

# Stop gracefully.
make stop

# Delete all fissile images.
docker rmi $(fissile show image)

# Re-create the images and then run them.
make images run
```

### My vagrant box is frozen. What can I do?

Try each of the following solutions sequentially:

* Run the `vagrant reload` command.
* Run `vagrant halt && vagrant reload` command.
* Manually stop the virtual machine and then run the `vagrant reload` command.
* Run the `vagrant destroy -f && vagrant up` command and then run `make vagrant-prep run` on the Vagrant box.

### Can I target the cluster from the host using the `cf` CLI?

You can target the cluster on the hardcoded `cf-dev.io` address assigned to a host-only network adapter.
You can access any URL or endpoint that references this address from your host.

### How do I connect to the Cloud Foundry database?

1. Use the role manifest to expose the port for the mysql proxy role
2. The MySQL instance is exposed at `192.168.77.77:3306`.
3. The default username is: `root`.
4. You can find the default password in the `MYSQL_ADMIN_PASSWORD` environment variable in the `~/scf/bin/settings/settings.env` file on the Vagrant box.

### How do I add a new BOSH release to SCF?

1. Add a Git submodule to the BOSH release in `./src`.
2. Mention the new release in `.envrc`
3. Modify the `role-manifest.yml`:

    1. Add new roles or change existing ones
    1. Add exposed environment variables (`yaml path: /configuration/variables`).
    1. Add configuration templates (`yaml path: /configuration/templates` and `yaml path: /roles/*/configuration/templates`).

1. Add defaults for your configuration settings to `~/scf/bin/settings/settings.env`.
1. If you need any extra default certificates, add them to `~/scf/bin/settings/certs.env`.
1. Add generation code for the certs to `~/scf/bin/generate-dev-certs.sh`.
1. Add any opinions (static defaults) and dark opinions (configuration that must be set by user) to `./container-host-files/etc/scf/config/opinions.yml` and `./container-host-files/etc/scf/config/dark-opinions.yml`, respectively.
1. Change the `./Makefile` so it builds the new release:
    1. Add a new target `<release-name>-release`.
    1. Add the new target as a dependency for `make releases`.
1. Test the changes.
1. Run the `make <release-name>-release compile images run` command.

### What does my dev cycle look like when I work on Component X?

1. Make a change to component `X`, in its respective release (`X-release`).
1. Run `make X-release compile images run` to build your changes and run them.

#### Bumping a version in a release (or just make a change)

For this example, lets suppose we want to update a release to a later tag.
First of all checkout the desired commit:

```
host> cd src/loggregator-release/ && git checkout v81
```

If the submodules has submodules of each own, you will have to "sync" and "update"
them as well. See "Pulling updates" in [Deploying section](#deploying).

Then from inside the vagrant box regenarate the image for this release:

```
vagrant> cd scf && make loggregator-release compile images
```

Then let kubernetes know about this new image and use it:

```
vagrant> make kube
```

And restart the pods:

```
vagrant> make stop && make run
```

If everything works, then you probably need to update the .gitmodules to point
to the new submodule commit SHA:

```
host> git add src/loggregator-release && git commit -am "Bumped the version of loggregator-release"
host> git push origin develop # or whatever your remote and branch are called
```

### How do I expose new settings via environment variables?

1. Edit `./container-host-files/etc/scf/config/role-manifest.yml`:

    1. Add the new exposed environment variables (`yaml path: /configuration/variables`).
    1. Add or change configuration templates:

        1. `yaml path: /configuration/templates`
        1. `yaml path: /roles/*/configuration/templates`

1. Add defaults for your new settings in `~/scf/bin/settings/settings.env`.
1. If you need any extra default certificates, add them to `~/scf/bin/dev-certs.env`.
1. Add generation code for the certificates here: `~/scf/bin/generate-dev-certs.sh`
1. Rebuild the role images that need this new setting:

    ```bash
    docker stop <role>
    docker rmi -f fissile-<role>:<tab-for-completion>
    make images run
    ```

    __Tip:__ If you do not know which roles require your new settings, you can use the following catch-all:

    ```bash
    make stop
    docker rmi -f $(fissile show image)
    make images run
    ```

### How do I bump the submodules for the various releases?

__Note:__ Because this process involves cloning and building a release, it may take a long time.

This section describes how to bump all the submodules at the same
time. This is the easiest way because we have scripts helping us
here.

1. On the host machine run

    ```bash
    bin/update-releases.sh <RELEASE>
    ```

    to bump to the specified release of CF. This pulls the information
    about compatible releases, creates clones and bumps them.

1. Next up, we need the BOSH releases for the cloned and bumped submodules. Run

    ```bash
    bin/create-clone-releases.sh
    ```

    This command will place the log output for the individual releases
    into the sub directory `LOG/ccr`.

1. With this done we can now compare the BOSH releases of originals
   and clones, telling us what properties have changed (added,
   removed, changed descriptions and values, ...).

    On the host machine run

    ```bash
    diff-releases.sh
    ```

    This command will place the log output and differences for the
    individual releases into the sub directory `LOG/dr`.

1. Act on configuration changes:

    __Important:__ If you are not sure how to treat a configuration
    setting, discuss it with the SCF team.

    For any configuration changes discovered in step the previous
    step, you can do one of the following:

        * Keep the defaults in the new specification.
        * Add an opinion (static defaults) to `./container-host-files/etc/scf/config/opinions.yml`.
        * Add a template and an exposed environment variable to `./container-host-files/etc/scf/config/role-manifest.yml`.

    Define any secrets in the dark opinions file `./container-host-files/etc/scf/config/dark-opinions.yml` and expose them as environment variables.

        * If you need any extra default certificates, add them here: `~/scf/bin/dev-certs.env`.
        * Add generation code for the certificates here: `~/scf/bin/generate-dev-certs.sh`.

1. Evaluate role changes:

    1. Consult the release notes of the new version of the release.
    1. If there are any role changes, discuss them with the SCF team, [follow steps 3 and 4 from this guide](#how-do-i-add-a-new-bosh-release-to-scf).

1. Bump the real submodule:

    1. Bump the real submodule and begin testing.
    1. Remove the clone you used for the release.

1. Test the release by running the `make <release-name>-release compile images run` command.

### Can I suspend or resume my vagrant VM?

1. Run the `vagrant reload` command.
2. Run the `make run` command.

### How do I develop an upstream PR?

* If our submodules are close to the `HEAD` of upstream and no merge conflicts occur, follow [the steps described here](#if-im-working-on-component-x-how-does-my-dev-cycle-look-like).
* If merge conflicts occur, or if the component is referenced as a submodule, and it is not compatible with the parent release, work with the SCF team to resolve the issue on a case-by-case basis.

## How do I publish SCF and BOSH images?

1. Ensure that the Vagrant box is running.
1. `ssh` into the Vagrant box.
1. To tag the images into the selected registry and to push them, run the `make tag publish` command.
1. This target uses the `make` variables listed below to construct the image names and tags:

    | Variable       | Default          | Meaning |
    | -------------- | ---------------- | ------- |
    | IMAGE_REGISTRY | _empty_          | The name of the trusted registry to publish to |
    | IMAGE_PREFIX   | scf              | The prefix to use for image names (must not be empty) |
    | IMAGE_ORG      | splatform        | The organization in the image registry |
    | BRANCH         | _current branch_ | The tag to use for the images |

1. To publish to the standard trusted registry run the `make tag publish` command, for example:

    ```bash
    make tag publish IMAGE_REGISTRY=docker.example.com/
    ```

## How do I generate certs for pre-built Docker images?

1. Download the [scf-cert-generator.sh](https://github.com/SUSE/scf/blob/develop/docker-images/cert-generator/scf-cert-generator.sh) script
1. Run it, setting the command line options according to your cluster
1. Provide the resulting YAML file to helm as a values.yaml file:

    ```bash
    helm install ... -f scf-cert-values.yaml
    ```

## How do I use an authenticated registry for my Docker images?

For testing purposes we can create an authenticated registry right inside
the Vagrant box.  But the instructions work just the same with a pre-existing
local registry.

The environment variables must be exported before changing into the `scf/`
directory. Otherwise `direnv` will remove the settings when switching to the
`src/uaa-fissile-release/` dir and back:

```
vagrant ssh
export FISSILE_DOCKER_REGISTRY=registry.cf-dev.io:5000
export FISSILE_DOCKER_USERNAME=admin
export FISSILE_DOCKER_PASSWORD=changeme
cd scf
time make vagrant-prep
```

`make secure-registries` will disallow access to insecure registries and register
the interal CA cert before restarting the docker daemon.

`make registry` will create a local docker registry re-using the router_ssl certs
and using basic auth. `make publish` will push all images to this registry:

```
make secure-registries
make registry
docker login -u $FISSILE_DOCKER_USERNAME -p $FISSILE_DOCKER_PASSWORD $FISSILE_DOCKER_REGISTRY
make publish
docker logout $FISSILE_DOCKER_REGISTRY
```

Log out to make sure that kube is using the registry credentials from the
helm chart and not the cached docker session.

Now delete all the local copies of the images. direnv allow is required to call
fissile from the UAA directory, and `FISSILE_REPOSITORY` needs to be overridden
from the `scf` setting that is inherited:

```
fissile show image | xargs docker rmi
cd src/uaa-fissile-release/
direnv allow
FISSILE_REPOSITORY=uaa fissile show image | xargs docker rmi
docker images
cd -
```

Now create an SCF and UAA instance via the helm chart and confirm that all
images are fetched correctly. Run smoke tests for final verification:

```
make run
pod-status --watch
docker images
make smoke
```

If the registry API needs to be accessed via curl, then it is easier to just use basic auth,
which can be requested by setting:

```
...
export FISSILE_DOCKER_AUTH=basic
make registry
curl -u ${FISSILE_DOCKER_USERNAME}:${FISSILE_DOCKER_PASSWORD} https://registry.cf-dev.io:5000/v2/
```

## Using Persi NFS


### Running a test NFS server

```bash
# Enable NFS modules
sudo modprobe nfs
sudo modprobe nfsd

docker run -d --name nfs \
    -v "[SOME_DIR_YOU_WANT_TO_SHARE_ON_YOUR_HOST]:/exports/foo" \
    -p 111:111/tcp \
    -p 111:111/udp \
    -p 662:662/udp \
    -p 662:662/tcp \
    -p 875:875/udp \
    -p 875:875/tcp \
    -p 2049:2049/udp \
    -p 2049:2049/tcp \
    -p 32769:32769/udp \
    -p 32803:32803/tcp \
    -p 892:892/udp \
    -p 892:892/tcp \
    --privileged \
    viovanov/nfs-server /exports/foo
```

### Allow access to the NFS server

- Security group JSON file (nfs-sg.json)
```json
[
    {
        "destination": "192.168.77.77",
        "protocol": "tcp",
        "ports": "111,662,875,892,2049,32803"
    },
    {
        "destination": "192.168.77.77",
        "protocol": "udp",
        "ports": "111,662,875,892,2049,32769"
    }
]
```

```bash
# Create the security group - JSON above
cf create-security-group nfs-test nfs-sg.json
# Bind security groups for containers that run apps
cf bind-running-security-group nfs-test
# Bind security groups for containers that stage apps
cf bind-staging-security-group nfs-test
```

### Creating and testing a service

#### Get the pora app

```
git clone https://github.com/cloudfoundry/persi-acceptance-tests.git
cd persi-acceptance-tests/assets/pora
cf push pora --no-start
```

#### Test that writes work
```bash
# Enable the Persi NFS service
cf enable-service-access persi-nfs

# Create a service and bind it
cf create-service persi-nfs Existing myVolume -c '{"share":"192.168.77.77/exports/foo"}'
cf bind-service pora myVolume -c '{"uid":"1000","gid":"1000"}'

# Start the app
cf start pora
# Test the app is available
curl pora.cf-dev.io
# Test the app can write
curl pora.cf-dev.io/write
