# autoelevate-autotask
Autoelevate - Install Script - Calls in Autotask / Datto RMM ObjectID for referencing customer and device


This single script needs to be run from the customer device.
-- It will look for the Datto RMM Device ID
-- Then referance the Device ID against Autotask PSA to find the correct customer
-- This allows the devices to be matched even if two or more devices have the same hostname.

You will need to generate an Autotask API Key for the applocation install

I use a seperate Key for AutoElevate ticket processing so that way if this script has issues it will not cause a problem to the two way traffic between autoelevate and Autotask.

You will need to fill in the following items

$LICENSE_KEY = "AutoElevate LicenseKey"

$API_USER_NAME = 'Autotask API Username'
$API_SECRET = 'Autotask API Password'
$API_INTEGRATION_CODE = 'Autotask Intigration Code' #Datto Tracking Identifier
