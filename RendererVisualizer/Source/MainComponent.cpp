/*
Copyright (c) 2024 Fritz Menzer

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "MainComponent.h"

//==============================================================================
MainComponent::MainComponent()
{
  setSize (600, 400);
  // create listener shape
  listenerShape.addTriangle(-0.35,0.1,0,-0.3,0.35,0.1);
  // create walls to be drawn
  walls.startNewSubPath(XOFFS,0);
  walls.lineTo(XOFFS,L1);
  walls.lineTo(XOFFS+W1,L1);
  walls.lineTo(XOFFS+W1,L1a+W2);
  walls.lineTo(XOFFS+W1+L2,L1a+W2);
  walls.lineTo(XOFFS+W1+L2,L1a);
  walls.lineTo(XOFFS+W1,L1a);
  walls.lineTo(XOFFS+W1,0);
  walls.closeSubPath();
  // Bind the socket to a port
  bool isBound = socket.bindToPort(53914);
  if (!isBound)
    juce::Logger::writeToLog("Failed to bind to port");
  startTimer(10); // 10 ms => 100 times per second
}

MainComponent::~MainComponent()
{
  socket.shutdown();
}

//==============================================================================
void MainComponent::paint (juce::Graphics& g)
{
  // (Our component is opaque, so we must completely fill the background with a solid colour)
  g.fillAll (getLookAndFeel().findColour (juce::ResizableWindow::backgroundColourId));
  
  juce::Path myPath = walls;
  juce::AffineTransform at = computeAT();
  myPath.applyTransform(at);
  
  // Set the colour and draw the floor and walls
  g.setColour(juce::Colours::lightgrey);
  g.fillPath(myPath);
  g.setColour(juce::Colours::black);
  g.strokePath(myPath, juce::PathStrokeType(1.5f));
  
  // draw listener
  juce::AffineTransform oat = juce::AffineTransform::rotation(lazi)
    .translated(juce::Point<float>(lx,ly))
    .followedBy(at);
  myPath = listenerShape;
  myPath.applyTransform(oat);
  g.setColour(juce::Colours::blue);
  g.strokePath(myPath, juce::PathStrokeType(1.0f));
  // display listener height
  g.setFont(juce::Font (16.0f));
  g.setColour(juce::Colours::white);
  g.drawText("Listener height: " + juce::String(lz) + " m", getLocalBounds(), juce::Justification::centred, true);
}

void MainComponent::resized()
{
}
