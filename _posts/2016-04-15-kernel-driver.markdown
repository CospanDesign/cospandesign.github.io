---
layout: post
title:  "Writing a Kernel Driver"
date:   2016-04-15 10:00:00 -0400
categories: Linux,Kernel,Driver
---

# Intro

I have worked on a few kernel drivers before and every time I spend a couple of days setting up the build environment and figuring out how to do everything again. This is my attempt at helping myself out in the future. So to future Dave, you owe me a beer.

There are a lot of different types of modules to build, this one is aimed at presenting a file interface for a hardware device. Basically it allows userland access to your device using both file operations and sysfs. There are a lot of other ways to build modules. Perhaps in the future the git repo can be branched to accomodate these variations.

This guide will walk through:

  * **Setup** The initial setup when building a module include preparing the host and downloading the code.
  * **Design** The design of the module
  * **Code-Build-Debug-Repeat** Debugging

To make things easy for this guide I'll declare the following things:

  * Module Name: **wallaby**
  * Module Location: **~/Projects/wallaby**

# Setup

The one time setup consists of the following steps:

  * Setting up the system
  * Cloning the github repo
  * Rename the module

## System Setup

Setup Ubuntu to build the kernel module. We'll need both build-essentials and the kernel headers.

{% highlight bash %}
sudo apt-get install linux-headers-$(uname -r)) build-essentials
{% endhighlight %}

## Getting the skeleton

I created a skeleton that can help get started with the build process

[Kernel Module Skeleton](https://github.com/CospanDesign/kernel-module)

Clone this repository to somewhere on your system.

{% highlight bash %}
git clone https://github.com/CospanDesign/kernel-module.git wallaby
{% endhighlight %}

## Modifying the Skeleton with your module name

There is a script that needs to be run one time that will rename the modules and all references to that module. It should probably be deleted after it's use or you may inadvertently rename things later on.

# Design

## ioctrl vs sysfs
As stated in the intro this is one type of driver focused on presenting a file like interface to a hardware device. File interfaces are useful becaues most programming languages can interact with files. There is one issue. Sometimes we need to interact with our hardware in a way that doesn't make sense using 'read' or 'write'. For example in order to configure a UART to operate at a specific baudrate users would need to use 'out of band' signals called 'Input Output Control' or ioctrl.

If you have ever used ioctl you can appreciate that it was frustrating to say the least. The main reason for this is because the user needed to know what specific ioctl corresponded to what function as well as what values were valid. The problem was exhaserbated by the fact that an ioctl for one driver could be completely different foa another driver. As can be imagined there were great attempts to figure this issue out with 'known ioctl numbers' as well as other such mechanisms.

A newer approach to controlling devices, drivers and general system functionality was introduced with sysfs. There are a lot of resources on the web describing the history and benefits but suffice to say we will be using sysfs to configure our device.

## Anatomy of a driver

A driver can be broken down into four regions.

  * Hardware Detection and Removal handlers.
  * Driver Setup and Tear Down.
  * User Interface.
  * General Driver Infrastructure.

### Hardware Detection and Removal

When a driver is loaded into the kernel it needs to tell the kernel how to identify the device the driver will control. Depending on the driver you will write some other piece of code will 





# Code-Build-Debug-Repeat

Now that all the configuration is done it's time build and test your code

