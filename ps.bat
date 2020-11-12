runas /user:Administrator ps.bat

cd C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TestWindow

vstest.console.exe C:\Users\devrpvm-user\Documents\PSUnitTest\bin\Debug\PSUnitTest.dll /logger:trx;LogFileName=C:\Users\devrpvm-user\Documents\PSUnitTest\TestResults\PSUnitResults.trx