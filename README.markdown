# Raca

A simple gem for interacting with Rackspace cloud APIs. The following APIs are
supported:

* Identity
* Cloud Files
* Cloud Servers

Raca intentionally has no dependencies outside the ruby standard library.

If loaded alongside Rails, it will utilise the rails cache to avoid repeated
requests to the rackspace identity API.

## Installation

    gem install raca

## Usage

For full usage details check the documentation for each class, but here's
a taste of the basics.

### Regions

Many of the Rackspace cloud products are available in multiple regions. When
required, you can specify a region using a symbol with the 3-letter region code.

Currently, the following regions are valid:

* :ord - Chicago
* :iad - Northern Virginia
* :syd - Sydney
* :dfw - Dallas-Fort Worth
* :hkg - Hong Kong

### Identity

To authenticate and begin any interaction with rackspace, you must create a
Raca::Account instance.

    account = Raca::Account.new("username", "api_key")

You can view the token that will be used for subsequent requests:

    puts account.auth_token

List the available APIs:

    puts account.service_names

... and then view the URLs for each service:

    puts account.public_endpoint("cloudFiles", :ord)

### Cloud Files

Using an existing Raca::Account object, retrieve a collection of Cloud Files
containers in a region like so:

    ord_containers = account.containers(:ord)

You can retrieve a single container from the collection:

    dir = ord_containers.get("container_name")

Retrieve some metadata on the collection:

    put ord_containers.metadata

With a single container, you can perform a range of operations on the container
and objects inside it.

    dir = ord_containers.get("container_name")

Download a file:

    dir.download("remote_key.txt", "/home/jh/local_file.txt")

Upload a file:

    dir.upload("target_path.txt", "/home/jh/local_file.txt")

List keys in the container, optionally limiting the results to those
starting with a prefix:

    puts dir.list
    puts dir.list(prefix: "subdir/")

Delete an object:

    dir.delete("target_path.txt")

View metadata on the container:

    puts dir.metadata
    puts dir.cdn_metadata

Enable access to the container contents via a public CDN. Use this with caution, it will make *all* objects public!

It accepts an argument telling the CDN edge nodes how long they can cache each object for (in seconds).

    dir.cdn_enable(60 * 60 * 24) # 1 day

Purge an object from the CDN:

    dir.purge_from_akamai("target_path.txt", "notify@example.com")

Generate a public URL to an object in a private container. The second argument
is the temp URL key that can be set using Raca::Containers#set_temp_url_key

    ord_containers = account.containers(:ord)
    ord_containers.set_temp_url_key("secret")
    dir = ord_containers.get("container_name")
    puts dir.temp_url("remote_key.txt", "secret", Time.now.to_i + 60)

### Cloud Servers

Using an existing Raca::Account object, retrieve a collection of Cloud Servers
from a region like so:

    ord_servers = account.servers(:ord)

You can retrieve a existing server from the collection:

    a_server = ord_servers.get("server_name")

Retrieve some details on the server:

    put a_server.metadata

You can use the collection to create a brand new server:

    a_server = ord_servers.create("server_name", "1Gb", "Ubuntu 10.04 LTS")

### Users

Using an existing Raca::Account object, retrieve a collection of Users like so:

    users = account.users

You can retrieve an existing user from the collection:

    a_user = users.get("username")

You can display details for each user with the details method:

    a_user = users.get("username")
    a_user.details

## General API principles

Methods that make calls to an API should never return a raw HTTP response
object. If a sensible return value is expected (retrieving metadata, listing
matches, etc) then that should always be returned. If return value isn't obvious
(change remote state, deleting an object, etc) then a simple boolean or similar
should be returned to indicate success.

If an unexpected error occurs (a network timeout, a 500, etc) then an exception
should be raised.


## Why not fog?

[fog](http://rubygems.org/gems/fog) is the [official](http://developer.rackspace.com)
ruby library for interacting with the Rackspace API. It is a very capable
library and supports much more of the API than this modest gem.

As of version 1.20.0, fog supports dozens of providers, contains ~152000 lines
of ruby and adds ~500ms to the boot time of our rails apps. raca is a
lightweight, rackspace-only alternative with minimal dependencies that should
have a negligable impact on application boot times. Version 0.3 has ~700 lines of
ruby (excluding specs). It also does *much* less than fog. We can't have our cake
and eat it too.

## Compatibility

The Raca version number is < 1.0 because it's highly unstable. Until we release
a 1.0.0, consider the API of this gem to be unstable.

## License

This library is released undr the MIT License. See the included MIT-LICENSE file
for further details
