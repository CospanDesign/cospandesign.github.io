---
layout: post
title:  "FPGA PCIE Host Interface"
date:   2016-05-09 09:29:59 -0400
categories: Linux,Kernel,FPGA,Driver
---

# Intro

I worked on Nysa to allow users to interact with FPGA using their computer. Originally I started working with a UART interface but quickly I found the bottleneck of a 115K bitrate presented. I worked on a USB2 FIFO interface using the FTDI FT2232H. With this higher throughput I was able to demonstrate playing videos on a remote LCD screen and reading video from a camera but this interface still suffers from throughput issues.

I've been working on other solutions including USB 3.0 and SDIO and they are promising but the approach that is the most attractive is PCIE. I'm writing this to talk about the challenges that I am working on and working through.


# PCIE and FPGAs

PCIE is a high throughput protocol available on most modern motherboards as well as some embedded boards including the Intel Galileo and NVIDIA TK1 and TX1.

In order to bring up PCIE on an FPGA you need to generate a PCIE core. All the large FPGA vendors provide PCIE cores in some fashion. My experience only lies in the Xilinx tools. I used coregen to generate a PCIE core with an AXI interface. I'll go into more of my PCIE coregen choices later on.

# Xilinx PCIE-AXI Interface

The core has a relatively simple AXI stream interface. If you haven't had a chance to use AXI it's very powerful. The AXI _streaming interface_ is different from the full AXI interface because it only contains the data in and data out bus instead of all the command, address write, address read and acknowledgement bus. I was able to write and verify a simple AXI to BRAM converter pretty quickly.

The rest of the interface is essentially flags and registers you can read and write to/from the Xilinx PCIE core.

# First Demo

The goals of my first demo were:

1. Observe PCIE linkup with the host computer
2. Observe raw reads and writes from the host


When starting this endevore I knew there was a lot of oportunities to paint myself into a corner or fall into debug pergatory where I would spend more time thorizing what could be wrong with the design. Instead I spent most of my time in simulation.

Instead of desiging the PCIE core to behave like the interface between the host computer and the FPGA I designed it to be a slave for a known good Nysa interface (USB 2.0 8-bit FIFO) This way I can observe and manipulate all the flags and registers of the PCIE core without having to rebuild it everytime I want to test a feature.

During simulation I used [cocotb](http://github.com/potentialventures/cocotb) extensively. I interacted with my core in the same way the Xilinx generated core does (through AXI stream interface). I wrote an AXI bus interface using Cocotb. Now, In order to write data to my core in simulation I send a data array to an AXI bus Python object and it will behave like the data portion of the Xilinx PCIE core. 

I used the [Xilinx 1052 Application Note](http://www.xilinx.com/support/documentation/application_notes/xapp1052.pdf) as the starting point for my design. The application note provided a kernel source which allowed users to use mmap to read and write blocks of data to the FPGA.


Finally time to bring up my core. Fortunatley I see this immediately:

{% highlight bash %}

$ lspci

...
01:05.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] RS880 [Radeon HD 4200]
02:00.0 Network controller: Ralink corp. RT5390 Wireless 802.11n 1T/1R PCIe
03:00.0 RAM memory: Xilinx Corporation Default PCIe endpoint ID
04:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL8101/2/6E PCI Express Fast/Gigabit Ethernet controller (rev 05)

{% endhighlight %}

Wow, immediately I see:

**03:00.0 RAM memory: Xilinx Corporation Default PCIe endpoint ID**

It took me a while to adapt there kernel module to my device but I finally start observing a write transaction with the host computer


