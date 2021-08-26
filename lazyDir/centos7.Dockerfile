##############################
# General level requirements #
##############################

# Pull base image from official repo
FROM centos:centos7.9.2009

# Import local GPG keys and enable epel repo
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 && \
    yum -q clean all && \
    yum -q makecache && \
    yum -y install --setopt=tsflags=nodocs \
      epel-release \
    && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 && \
    yum -q -y clean all --enablerepo='*'

# Install common requirements
RUN INSTALL_PKGS="git unzip wget which" && \
    yum -q clean expire-cache && \
    yum -q makecache && \
    yum -y install --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum -q -y clean all --enablerepo='*'

# Prepare locales
ARG locale=en_US.UTF-8
ENV LANG "${locale}"
ENV LC_ALL "${locale}"

# Configure desired timezone
ENV TZ=Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

###############################
# Enable Software Collections #
###############################

# Add repos, keys and tools
RUN yum -q clean expire-cache && \
    yum -q makecache && \
    yum -y install --setopt=tsflags=nodocs \
      centos-release-scl \
      scl-utils \
    && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo && \
    yum -q -y clean all --enablerepo='*'

# Enable SCLs for any later bash session
COPY scl_enable.sh /usr/local/bin/scl_enable
ENV BASH_ENV="/usr/local/bin/scl_enable" \
    ENV="/usr/local/bin/scl_enable" \
    PROMPT_COMMAND=". /usr/local/bin/scl_enable"

##################################
# Application level requirements #
##################################

# Install Ruby 2.6 from SCLO repo
RUN INSTALL_PKGS="rh-ruby26-ruby rh-ruby26-ruby-devel rh-ruby26-ruby-libs rh-ruby26-rubygem-bundler rh-ruby26-rubygems" && \
    yum -q clean expire-cache && \
    yum -q makecache && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    yum -q -y clean all --enablerepo='*'

# Install extra dev tools
RUN INSTALL_PKGS="gcc gcc-c++ make zlib-devel" && \
    yum -q clean metadata && \
    yum -q makecache && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    yum -q -y clean all --enablerepo='*'

# Install NodeJS 10 from SCLO repo
RUN INSTALL_PKGS="rh-nodejs10-nodejs rh-nodejs10-npm" && \
    yum -q clean metadata && \
    yum -q makecache && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    yum -q -y clean all --enablerepo='*'

# Enable SCLs for any later bash session
COPY scl_enable.sh /usr/local/bin/scl_enable
ENV BASH_ENV="/usr/local/bin/scl_enable" \
    ENV="/usr/local/bin/scl_enable" \
    PROMPT_COMMAND=". /usr/local/bin/scl_enable"
COPY container-entrypoint.sh /usr/local/bin/container-entrypoint
RUN chmod 0755 /usr/local/bin/container-entrypoint
ENTRYPOINT [ "/usr/local/bin/container-entrypoint" ]

###########################
# User level requirements #
###########################

# Parameters for default user:group
ARG uid=1000
ARG user=jekyll
ARG gid=1000
ARG group=jekyll

# Add or modify user and group for build and runtime (convenient)
RUN id ${user} > /dev/null 2>&1 && \
    { groupmod -g "${gid}" "${group}" && usermod -md /home/${user} -s /bin/bash -g "${group}" -u "${uid}" "${user}"; } || \
    { groupadd -g "${gid}" "${group}" && useradd -md /home/${user} -s /bin/bash -g "${group}" -u "${uid}" "${user}"; }

# Copy requirements in non-root user home directory
COPY Gemfile Gemfile.lock "/home/${user}/"
RUN chown "${user}:${group}" "/home/${user}/Gemfile"*

# Switch to non-root user
USER ${user}
WORKDIR /home/${user}

# Prepare user variables
ENV USER ${user}
ENV HOME=/home/${user}

# Install required gems
RUN source /usr/local/bin/scl_enable && \
    echo "gem: --no-document --user-install --bindir /home/${user}/bin" >> /home/${user}/.gemrc && \
    echo "gempath: /home/${user}/.gem/ruby:/home/${user}/.bundle/gems/ruby/2.6.0:/opt/rh/rh-ruby26/root/usr/share/gems" >> .gemrc && \
    gem install bundler --version `sed -n -r -e '/BUNDLED WITH/,$ { s/\s+([.0-9]+)/\1/ p }' Gemfile.lock` && \
    bundle config --global path /home/${user}/.bundle/gems && \
    bundle config --global bin /home/${user}/bin && \
    bundle install && \
    rm -rf /home/${user}/.bundle/cache

# Get script directory from lazyLib at last to avoid warning w/o invalidating the cache 
ARG dir=.
