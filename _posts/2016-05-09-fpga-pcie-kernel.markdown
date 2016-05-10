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


## Write Path

### Different Modules

#### Ingress buffer manager.

  - [ ] Tells the PCIE controller that it is waiting for a buffer from the host computer.
  - [ ] Receives buffer status updates from the host computer when new data is available. Keep track of which one has come in first.
  - [ ] Supply the PCIE controller with a tag to use.
  - [ ] Listen for a commit from the PCIE controller that it has requested data from the host.
  - [ ] The IBM should listen for the PCIE ingress to receive a 'completion' tlp. The tag that is associated with it will determine the appropriate address. If multiple completion headed are required to finish a transaction the IBM updates the appropriate address and tag count. When it outputs the max count it is finished with a tag.
  - [ ] When a tag is finish it marks it as complete. The IBM keeps track of all the buffers being read from and the tags used to read that buffer. When all tags associated with a buffer is finished or all data is read the IBM notifies the controller that a buffer is done. The controller will then issue a status update to the host which will tell the host that the appropriate buffer is ready for new data.


#### Buffer builder:

In the end I need to populate the ping pong FIFO.
Verify data flows from the large 8k buffer to FIFOs in the correct order. The buffer builder us not responsible for the order, in fact the only responsibility it has is to populate the FIFOs correctly.

#### PCIE ingress

##### command context



##### completion context

In this context the PCIE ingress needs to recognize the complete TCP.
The entire process should recognize the TCP and respond by writing the data to the buffer builder at the correct address.
Actually the PCIE ingress doesn't manage the addresses. The ingress buffer manager does this.

##### register update context

Waits for the status buffer from the device to say buffers are available. Then populates either buffer and notifies the device that a buffer now has data.
Read in the buffer status from the host computer

Supply the correct tags to the PCIE egress


### Tests

#### Host Tests
  - [ ] `Host`: Write Register: Transmit a 32-bit Register value to `PCIE Ingress`
    - Expected Result:
      - `Host` -> `PCIE Ingress` Send 32-bit value to a register
  - [ ] `Host`: Send Read Command: Transmit a **Read Command**
    - Expected Result:
      - `Host` -> `PCIE Ingress` Send 32-bit **Read Command**
      - `PCIE Ingress` Parses and notifies `PCIE Control`
      - `Host` wait for **Status Update**
      - `PCIE Egress` -> `Host` send **Status Update** the **Buffer Done** ready will indicate where the data is located
      - `Host` repeats the above process until all of the data is read from the device
      - `Host` wait for final **Status Update** with **Done** flag asserted
      - `PCIE Egress` -> `Host` send Status Update the **Done** Flag will indicate the transaction is finished
  - [ ] `Host`: Send Write Command: Transmit a **Write Command** to `PCIE Ingress`
    - Expected Result:
      - `Host` -> `PCIE Ingress` Send 32-bit **Write Command**
      - `PCIE Ingress` Parse and notify `PCIE Control`
      - `Host` waits for **Status Update**
      - `PCIE Egress` -> `Host` send **Status Update** **Buffer Status** indicates which buffer is ready to be read from
      - `Host` repeats the above process until all of the data is sent to the device
      - `Host` waits for the Status Update with the **Done** flag asserted
      - `PCIE Egress` -> `Host` send Status Update the **Done** Flag will indicate the transaction is finished


#### PCIE Ingress Tests

  - [ ] `PCIE Ingress`: Receive **Address Register**: `Host` sends an address to the `PCIE Ingress`
    - Expected Result:
      - `PCIE Ingress` parses **Memory Write** TLP and address is correctly written to the **Address Register**
  - [ ] `PCIE Ingress`: Receive **Buffer Status**: `Host` sends a buffer status value to the `PCIE Ingress` indicating the status of the host side buffer
    - Expected Result:
      - `PCIE Ingress` parses **Memory Write** TLP and new data is correctly written to the **Buffer Status**
      - `PCIE Ingress` -> `Ingress Buffer Manager` within a write context the **Buffer Status Update** Signal is strobed
  - [ ] `PCIE Ingress`: Receive **Memory Write Command**: `Host` sends a memory write command to initiate a memory write transaction
    - Expected Result:
      - `PCIE Ingress` parses the **Memory Write** TLP and the data count is updated
      - `PCIE Ingress` -> `PCIE Control` strobes **Command Strobe**
  - [ ] `PCIE Ingress`: Receive **Completion Packet**: `Host` sends a packet of data in response to a memory read request from the `PCIE Control`
    - Expected Result:
      - `PCIE Ingress` parses the **Memory Write** TLP and the data count is updated
      - `PCIE Ingress` -> `PCIE Control` strobes **Command Strobe**

#### PCIE Control (Write Context) Tests

  - [ ] `PCIE Control`: Response to **Memory Write Command**: `PCIE Ingress` sends a **Memory Write Command** to `PCIE Control`
    - Expected Result:
      - `PCIE Ingress` -> `PCIE Control` strobe **Command Strobe**
      - `PCIE Control` enters the **Data Ingress Sub-State Machine**, specifically **Ingress Flow Control**
      - `PCIE Control` determines there is more data to read and proceeds to **Wait for Tag** State
      - `PCIE Control` waits for **Tag Ready** signal
      - `Ingress Buffer Manager` -> `PCIE Control`: assert **Tag Ready**
      - `PCIE Control` proceed to **Wait Flow Control**
      - `Credit Manager` -> `PCIE Control` assert **Flow Control Ready**
      - `PCIE Control` proceed to **Send Memory Request**
      - `PCIE Control` -> `PCIE Egress` send a request for a packet of data associated with a tag
      - `PCIE Control` update counts and register
      - `PCIE Control` if full buffer has been read send a **Status Update**
      - `PCIE Control` will proceed to **Ingress Flow Control**
      - `PCIE Control` -> `PCIE Egress` If all of the data has been read from the host assert **Done** Signal and initiate a **Status Update**

#### PCIE Egress Tests

  - [ ] `PCIE Egress`: Transmit Packet: When `PCIE Control` initiates a transaction the `PCIE Egress` will transmit all the data:
    - Expected Result:
      - `PCIE Control` -> `PCIE Egress` Assert **Send Packet**
      - `PCIE Egress` send TLP packet to host
      - `PCIE Egress` -> `PCIE Control` Assert **Send Packet Finished**
      ` `PCIE Control` -> `PCIE Egress` De-assert **Send Packet**
      - `PCIE Egress` -> `PCIE Control` De-Assert **Send Packet Finished**

#### Ingress Buffer Manager Tests

  - [ ] `Ingress Buffer Manager` Enable: Initialize when `PCIE Control` assert **enable** signal
    - Expected Result:
      - `PCIE Control` -> `Ingress Buffer Manager` assert **enable**
      - `Ingress Buffer Manager` Exits reset state and waits for **Buffer Status Update Strobe**
  - [ ] `Ingress Buffer Manager` Prepares Buffer: When `Ingress Buffer Manager` receives a **Buffer Status Update Strobe** from `PCIE Ingress` it configures **Tag State Machine** and indicates **Tag Ready** to `PCIE Control`
    - Expected Result:
      - `PCIE Control` -> `Ingress Buffer Manager` assert **Buffer Status Update Strobe**
      - `Ingress Buffer Manager` will read in the **Buffer Status** register and initiate the appropriate **Tag State Machine**
      - `Ingress Buffer Manager` -> `PCIE Control` will assert **Tag Ready** when a single tag within the **Tag State Machine** is in the ready state
  - [ ] `Ingress Buffer Manager` will generate the appropaite address: When `PCIE Ingress` receives a **Completion Packet** it generates the address that conforms to the tag. If the response to a tag is longer than the **Max Read Packet** `Ingress Buffer Manager` will update the appropriate address
    - Expected Result:
      - `PCIE Ingress` -> `Ingress Buffer Manager` tag value is updated when a new **Completion Packet** is detected
      - `Ingress Buffer Manager` generates an address associated with tag
      - `PCIE Ingress` -> `Ingress Buffer Manager` strobes **Completion Packet Finished** the `Ingress Buffer Manager` will update the count and address for that tag.
      - `Ingress Buffer manager` **Tag State Machine** Moves to finished status when all the data for a buffer is written to `Buffer Builder`
  - [ ] `Ingress Buffer Manager` Initiate FIFO Write: If `Ingress Buffer Manager` detects the entire buffer has been written down to the `Buffer Builder` the `Ingress Buffer Manager` will tell the `Buffer Builder` to populate the **Ingress FIFO** with the 4096 word data
    - Expected Result:
      - `Ingress Buffer Manager` will determine the amount of data that has been read from the host buffer and when the buffer is completely read it will signal the `Buffer Builder` to populate the **Ingress FIFO**
  - [ ] `Ingress Buffer Manager` Update `PCIE Control` when data has been written to **Ingress FIFO**: After the **Ingress FIFO** has been populated the buffer is finished and the `Buffer Builder` will indicate this status to `Ingress Buffer Manager`. It should assert **Buffer Finished** to `PCIE Control`
    - Expected Result:
      - `Ingress Buffer Manager` -> `Buffer Builder` assert appropriate **Populate FIFO** Flag
      - `Buffer Builder` -> `Ingress Buffer Manager` assert appropriate **FIFO Finished** Flag indicating it has successfully finished writing data from the buffer to the FIFO
      - `Ingress Buffer Manager` -> `PCIE Control` assert appropriate **Buffer Finished** Flag indicating that all data from `Host` has successfully been written to the Device
      - `PCIE Control` -> `Ingress Buffer Manager` assert appropriate **Buffer Finished Ack** Flag indicating `PCIE Control` has received flag
      - `Ingress Buffer Manager` Resets the **tag state machine** and resets the appropriate buffer's status

#### Credit Manager Tests

  - [ ] `Credit Manager` Initialize: When `Credit Manager` starts it reads the size of the various `Xilinx PCIE Core` buffers. At the initialization state the `Credit Manager` will populate it's local registers with the correct credits
    - Expected Result:
      - `Credit Manager` receives a reset signal and populates the appropriate registers
  - [ ] `Credit Manager` Flow Control Ready: Assert **Flow Control Ready** flag to indicate **PCIE Core** can handle the transaction
    - Expected Result:
      - When `Credit Manager` If space is available in the **Xilinx PCIE Core** assert **Flow Control Ready**
  - [ ] `Credit Manager` Decrement Count: Update PCIE Count when `PCIE Control` asserts **Flow Control Commit**
    - Expected Result:
      - `Credit Manager` -> `PCIE Control` assert **Flow Control Ready**
      - `PCIE Control` -> Strobe **Flow Control Commit**
      - `Credit Manager` Decrement Count
  - [ ] ``Credit Manager` Increment Count: Increment Packet Count when new data is read
    - Expected Result:
      - `PCIE Ingress` -> `Credit Manager` assert **Packet Finished**
      - `Credit Manager` Increment the appropraite data available

#### Buffer Builder Tests
  - [ ] `Buffer Builder` Populate FIFO: Populate appropriate **Ingress FIFO** when the associated signal is asserted
    - Expected Result:
      - `Ingress Buffer Manager` -> `Buffer Builder` Assert **PPFIFO Write Enable**
      - `Buffer Builder` Populate FIFO
      - `Buffer Builder` -> `Ingress Buffer Manager` Assert **PPFIFO Write Finished**
      - `Ingress Buffer Manager` -> `Buffer Builder` De-Assert **PPFIFO Write Enable**
      - `Buffer Builder` De-assert **PPFIFO Write Finished**
