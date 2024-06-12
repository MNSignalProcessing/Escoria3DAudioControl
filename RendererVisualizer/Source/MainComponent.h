/*
Copyright (c) 2024 Fritz Menzer

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#pragma once

#include <JuceHeader.h>

#define L1         66.0f
#define L1a        17.3f
#define W1          5.0f
#define L2         69.0f
#define W2          6.0f
#define XOFFS      11.0f
#define ROOMWIDTH  (L2+W1)
#define ROOMLENGTH (L1)
#define ROOMHEIGHT  5.0f

//==============================================================================
/*
 This component lives inside our window, and this is where you should put all
 your controls and content.
 */
class MainComponent  : public juce::Component, juce::Timer
{
public:
  //==============================================================================
  MainComponent();
  ~MainComponent() override;
  
  void timerCallback() override {
    char buffer[1024];
    juce::String senderIPAddress;
    int senderPort;
    
    // Check for incoming data
    int bytesRead = socket.read(buffer, sizeof(buffer), false, senderIPAddress, senderPort);
    while (bytesRead)
    {
      juce::String jsonString(juce::String(buffer, bytesRead));
      // DBG("Received data: " + jsonString);
      bytesRead = socket.read(buffer, sizeof(buffer), false, senderIPAddress, senderPort);
      
      juce::var parsedCmd;
      juce::Result result = juce::JSON::parse(jsonString, parsedCmd);
      
      if (!result.wasOk()) {
        DBG("Failed to parse JSON: " + result.getErrorMessage());
        return;
      }
      
      if (parsedCmd.hasProperty("lst")) {
        juce::var parsedJson = parsedCmd["lst"];
        // Access the 'pos' array from the parsed JSON
        if (parsedJson.hasProperty("pos") && parsedJson["pos"].isArray()) {
          juce::Array<juce::var>* posArray = parsedJson["pos"].getArray();
          
          // Ensure the array has at least two elements
          if (posArray->size() == 3) {
            // store listener position in instance variables
            lx = static_cast<float>((*posArray)[0]);
            ly = static_cast<float>((*posArray)[1]);
            lz = static_cast<float>((*posArray)[2]);

            if (parsedJson.hasProperty("azi")) {
              float azi = static_cast<float>(parsedJson["azi"]);
              // Log the values for further analysis
              DBG("[" << getSeconds() << "," << lx << "," << ly << "," << lz << "," << azi << "]");
              // store the listener azimuth
              lazi = azi/180.f*M_PI;
            }
            repaint();
          } else {
            DBG("Array 'lst.pos' does not have exactly 3 elements.");
          }
        } else {
          DBG("'lst.pos' is not an array or does not exist.");
        }
      } else {
        DBG("'lst' does not exist.");
      }
    }
  }
  
  //==============================================================================
  void paint (juce::Graphics&) override;
  void resized() override;
  
private:
  //==============================================================================
  float lazi;
  float lx,ly,lz;
  juce::DatagramSocket socket;
  juce::Path walls;
  juce::Path listenerShape;

  double getSeconds() {
      static double startTime = juce::Time::getMillisecondCounterHiRes() * 0.001;  // Convert start time to seconds
      return (juce::Time::getMillisecondCounterHiRes() * 0.001) - startTime;  // Current time in seconds minus start time
  }
  
  juce::AffineTransform computeAT() {
    juce::Rectangle<float> bounds = getLocalBounds().toFloat();
    juce::Rectangle<float> pathBounds = {0.f, 0.f, 88.f, 66.f};
    // Calculate scale factors for width and height
    float scale = juce::jmin(bounds.getWidth() / pathBounds.getWidth(),bounds.getHeight() / pathBounds.getHeight());

    // Calculate translation to center the object in the target bounds
    float translateX = bounds.getX() - pathBounds.getX() + (bounds.getWidth() - pathBounds.getWidth() * scale) / 2;
    float translateY = bounds.getY() - pathBounds.getY() + (bounds.getHeight() - pathBounds.getHeight() * scale) / 2;

    // Create and return the AffineTransform
    return juce::AffineTransform::scale(scale).followedBy(juce::AffineTransform::translation(translateX, translateY));
  };

  JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainComponent)
};

