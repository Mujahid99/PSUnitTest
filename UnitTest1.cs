using System;
using System.Diagnostics;
using System.Management.Automation;
using Microsoft.VisualStudio.TestTools.UnitTesting;


namespace PSUnitTest
{
    [TestClass]
    public class UnitTest1
    {
        public Microsoft.VisualStudio.TestTools.UnitTesting.TestContext TestContext { get; set; }


        [TestMethod]
        
        public void TestMethod1()
        {
            PowerShell ps = PowerShell.Create();

            ps.AddScript(@"C:\\Users\\devrpvm-user\\Documents\\PSUnitTest\\RpFunctions-Mujahid.ps1").AddScript(@"C:\\Users\\devrpvm-user\\Documents\\PSUnitTest\\Run-Har-Mujahid.ps1", true).AddParameter("-harFilePath", "C:\\Users\\devrpvm-user\\Documents\\grocerkey.har").AddParameter("-targetCluster", "stage").AddParameter("-sourceCluster", "integ").AddParameter("-username", "bb.retailer-admin@replenium.com").AddParameter("-password", "Test1234-").AddParameter("-clientid", "rp_admin").AddParameter("-preserveAuth", "s2libsi3u3bhh3paez4wkh4k6g4jht57kx44hqpxry6dxbkrsicq").Invoke();
            //add a file stored at c:\ location to the test result file
            this.TestContext.AddResultFile("C:\\Users\\devrpvm-user\\Documents\\PSUnitTest\\TestResults\\sample.xml");

            //Print the trx file name
            string testRunDirectory = TestContext.TestRunDirectory;
            string testRunTRXFileName = String.Concat(testRunDirectory, ".trx");
            Console.WriteLine("TestResult file : " + testRunTRXFileName);


            //Console.WriteLine(TestContext);
        }

    }
}
