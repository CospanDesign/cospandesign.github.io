---
layout: post
title:  "Porting an STM32 IAR Project to GCC"
date:   2017-11-25 20:00:00 -0400
categories: Linux,st,gcc
---

All of the example projects that I've download from ST are written for IAR IDE. IAR is a great tool, I use for a lot of demo projects but there are times when you might want to use GCC to build your project. The followings are steps that I've found works to port a project from IAR to GCC build toolchain on a Linux box, I use Ubuntu and I have not tested it out on other distributions.


At a high level these are the steps.

  * Setup your host machine.
  * Use STM32CubeMX to create build files.
  * Incorporate the Makefile into your project.
  * Download.
  * Debug.


## Setup Your Host Machine

Using 'apt' install the following packages, then build and install stutil.

### Commands

{% highlight bash %}
sudo apt install gcc-arm-none-eabi gdb-arm-none-eabi openocd build-essential cmake libusb-1.0-0 libusb-1.0.0-dev git
git clone https://github.com/texane/stlink.git
cd stlink
make release
cd build/Release
sudo make install
{% endhighlight %}

### Explanation

Install the appropriate tools. Clone the stlink git repo, build and install it. For custon installation there are more thourogh instructions here:

![STLink Build Instruction](https://github.com/texane/stlink/blob/master/doc/compiling.md)


## Use STM32CubeMX to Create Build Files


In a windows box, create a project with STM32CubeMX with your projects processor or board.

![Select Appropriate Board]({{ site.baseurl }}/assets/image/posts/st-port/select_bard.png)


Go to 'Project Settings'

![Project Settings]({{ site.baseurl }}/assets/image/posts/st-port/project_settings.png)


Name the project 'main' and set the toolchain to 'Makefile'

![Configure Project]({{ site.baseurl }}/assets/image/posts/st-port/configure_project.png)


From the generated project copy the 'Makefile' the '.s' file and the '.ld' file, these are the Makefile, the startup script assembly file and the linker script respectively.


![Take out the build files]({{ site.baseurl }}/assets/image/posts/st-port/build_files.png)



### Incorporate the Makefile into your project


Take the files from the previous step and add them to the base of your project of interest.

To make things simpler I'll adapt a project from ST that was originally designed for IAR and adapt it for GCC. Specifically I'll use this project:








