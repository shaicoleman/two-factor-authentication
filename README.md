# 2FA Example App

This is an example of a production ready 2FA example app, inspired by the `devise-two-factor` gem.

* Allows to log in with OTP or via backup codes
* Stores the backup codes and the OTP secrets encrypted in the DB
* Prevents brute force attempts of OTP codes and backup codes
* Ensures correct OTP setup, by requiring users to enter an OTP code
* Option to enforce 2FA enrollment, with a grace period
* Minimal gem dependencies
* Allows to view/download/print/copy the backup codes
* User friendly validations
* Gives friendly error messages when attempting to reuse OTP codes or backup codes
* Allows for delays (drift) when entering the OTP code
* Stores when 2FA has been enabled, and when the backup codes have been generated
* Shows how many backup codes remain available
* Generates QR code or allows manually entering the OTP secret
* I18n ready
