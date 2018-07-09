/*Copyright (c) 2018, Daniel Appleman

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation 
and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors 
may be used to endorse or promote products derived from this software without 
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND 
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

@istest
public without sharing class TestLedgerValidation {

    @testsetup
    public static void testSetup()
    {
        CollaborationGroup cg = new CollaborationGroup(Name='Ledger Validation',
                                    CollaborationType='Public') ;
        insert cg;  
    }

    @istest
    public static void TestValidationNoBatch() {

        // Insert test entries
        List<Ledger_Entry__c> entries = new List<Ledger_Entry__c>();
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp1', Opportunity_Amount__c = 5));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp2', Opportunity_Amount__c = 10));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp3', Opportunity_Amount__c = 15));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp4', Opportunity_Amount__c = 20));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp5', Opportunity_Amount__c = 25));
        Test.startTest();
        insert entries;
        Test.stopTest();

        List<Ledger_Entry__c> results = [Select ID, Block_Hash__c, Prior_Block_Hash__c, 
                                        Sequence__c, Transaction_Hash__c, Transaction_Field_List__c,
                                        Transaction_Date__c,
                                        Opportunity_Name__c, Opportunity_Amount__c 
                                        from Ledger_Entry__c Order By Sequence__c Asc];

        // Split the list - so we can validate first part of list, and second part
        List<Ledger_Entry__c> firstPart = new List<Ledger_Entry__c>();
        firstPart.add(results.remove(0));
        firstPart.add(results.remove(0));

        LedgerSupport validation1 = new LedgerSupport(firstPart);
        System.assertEquals(-1, validation1.validateOrderedBlockList());

        LedgerSupport validation2 = new LedgerSupport(results);
        System.assertEquals(-1, validation2.validateOrderedBlockList());

        // And validate the first and second records
        System.assert(LedgerValidation.validateOneBlockByHash(firstPart[0].Transaction_Hash__c));
        System.assert(LedgerValidation.validateOneBlockByHash(firstPart[1].Transaction_Hash__c));

    }

    @istest
    public static void TestValidationGoodChain() {

        // Insert test entries
        List<Ledger_Entry__c> entries = new List<Ledger_Entry__c>();
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp1', Opportunity_Amount__c = 5));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp2', Opportunity_Amount__c = 10));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp3', Opportunity_Amount__c = 15));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp4', Opportunity_Amount__c = 20));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp5', Opportunity_Amount__c = 25));
        insert entries;

        Test.startTest();
        LedgerScheduleValidation.validateLedger();  // Start the batch directly
        Test.stopTest();

        // Now check the status
        System.assertEquals(-1, LedgerValidation.BlockChainErrorRecord);

    }


    @istest
    public static void TestValidationBadChain()
    {
        // Insert test entries
        List<Ledger_Entry__c> entries = new List<Ledger_Entry__c>();
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp1', Opportunity_Amount__c = 5));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp2', Opportunity_Amount__c = 10));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp3', Opportunity_Amount__c = 15));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp4', Opportunity_Amount__c = 20));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp5', Opportunity_Amount__c = 25));
        insert entries;

        // We're going to modify some data
        LedgerSupport.AllowUpdateTriggers = true;
        Ledger_Entry__c badEntry = [Select ID, Opportunity_Name__c, Opportunity_Amount__c 
                                    from Ledger_Entry__c 
                                    where Opportunity_Name__c = 'opp3'];
        badEntry.Opportunity_Amount__c = 100;
        update badEntry;

        Test.startTest();
        LedgerValidation validationBatchClass = new LedgerValidation();
        ID batchID = Database.executeBatch(validationBatchClass);
        Test.stopTest();

        // Now check the status - we modified block #2
        System.assertEquals(2, LedgerValidation.BlockChainErrorRecord);

    }

    @istest
    public static void validateScheduler()
    {
        // Insert test entries
        List<Ledger_Entry__c> entries = new List<Ledger_Entry__c>();
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp1', Opportunity_Amount__c = 5));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp2', Opportunity_Amount__c = 10));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp3', Opportunity_Amount__c = 15));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp4', Opportunity_Amount__c = 20));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp5', Opportunity_Amount__c = 25));
        insert entries;

        Test.startTest();
        // Start the batch via Scheduler
        LedgerScheduleValidation sv = new LedgerScheduleValidation();
        system.schedule('Validate ledger', '0 0 0 1 1 ? 2100', sv);
        Test.stopTest();
        // Make sure the job was created
        List<AsyncApexJob> jobs = [Select ID from AsyncApexJob where ApexClass.Name = 'LedgerValidation'];
        system.assertEquals(1, jobs.size());
    }


}
