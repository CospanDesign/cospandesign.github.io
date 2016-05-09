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

When starting this endevore I knew there was a lot of oportunities to paint myself into a corner or fall into debug pergatory where I could spend more time thorizing what could be wrong with the design. I spent most of my time in simulation. I used cocotb
