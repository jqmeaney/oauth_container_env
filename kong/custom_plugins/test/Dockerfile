FROM kong:3.3

USER root

# Avoid apt interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Switch /etc/apt/sources.list to a known reliable mirror, then wipe old lists and install
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirror.math.princeton.edu/pub/ubuntu|g' /etc/apt/sources.list && \
    rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/* && \
    apt-get clean && \
    apt-get update --allow-releaseinfo-change --fix-missing && \
    apt-get install -y --no-install-recommends \
      unzip \
      luarocks \
    && luarocks install lua-resty-openidc \
    && rm -rf /var/lib/apt/lists/*

# Create Kong's plugin directory
RUN mkdir -p /usr/local/share/lua/5.1/kong/plugins/my-plugin

# Copy the plugin files
COPY handler.lua /usr/local/share/lua/5.1/kong/plugins/my-plugin/handler.lua
COPY schema.lua /usr/local/share/lua/5.1/kong/plugins/my-plugin/schema.lua

# Set proper permissions
RUN chmod -R 777 /usr/local/share/lua/5.1/kong/plugins/my-plugin

# Copy Kong's declarative configuration file
COPY kong.yml /usr/local/kong/kong.yml

# Set environment variables
ENV KONG_DATABASE=off
ENV KONG_LOG_LEVEL=debug
ENV KONG_DECLARATIVE_CONFIG=/usr/local/kong/kong.yml
ENV KONG_PLUGINS="bundled,my-plugin"
ENV KONG_ADMIN_LISTEN=0.0.0.0:8001
ENV KONG_PROXY_LISTEN=0.0.0.0:8000

USER kong


