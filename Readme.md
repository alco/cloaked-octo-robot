Introduction
============

This is general introduction to Elixir aimed at a wide audience: from people who are new to both Erlang and Elixir to programming veterans who are interested in Elixir's design and philosophy.

In this tutorial I will guide you from a basic TCP echo server to a fully functioning HTTP web-server able to server static and dynamic content. Currently, this is still very much a WIP (work in progress).

Preliminary table of contents:

1. [Building an echo server](https://github.com/alco/cloaked-octo-robot/blob/master/1%20-%20Echo%20server.md)
2. [Implementing request handlers](https://github.com/alco/cloaked-octo-robot/blob/master/2%20-%20Request%20handlers.md)
3. [Intro to HTTP](https://github.com/alco/cloaked-octo-robot/blob/master/3%20-%20Intro%20to%20HTTP.md)
4. [Our first web server]()
5. [Advanced HTTP techniques]()
6. [Introducing OTP]()

If you find any given part two easy, you may safely skim over the text, take a look at the code and proceed to the next part which describes more advanced material.


---

Elixir is built on top of the Erlang VM. Most of the system-level concepts that will be explained in this tutorial are taken directly from Erlang: processes, messages, modules, functions. In the text, Erlang will be mentioned every time one of its concepts is explained. Elixir will only be mentioned where an Elixir-specific feature is described.

If you're serious about mastering Elixir, you should also be willing to learn Erlang.
