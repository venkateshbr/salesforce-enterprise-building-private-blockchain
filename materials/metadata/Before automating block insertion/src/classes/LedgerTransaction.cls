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

public without sharing class LedgerTransaction {
    
    private Ledger_Entry__c entry;

    public LedgerTransaction(Ledger_Entry__c currentEntry) {
        entry = currentEntry;
    }

    private List<String> getNewFieldList()
    {
        // Retreive the current list from somewhere - maybe custom metadata?
        List<String> newFields = new List<String>{'Opportunity_Name__c', 'Opportunity_Amount__c'};
        // Always include the standard transaction fields
        newFields.add('Transaction_Date__c');
        newFields.add('Transaction_Field_List__c');

        // Get the map of existing fields on the Object
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Ledger_Entry__c.fields.getMap();

        // Validate each field
        for(String fieldName: newFields)
        {
            // In a real app, you'd also set some debugging information
            if(!fieldMap.containsKey(fieldName)) return null;
            Schema.DescribeFieldResult fr = fieldMap.get(fieldName).getDescribe();
            if(fr.isCalculated() || fr.isIdLookup()) return null;
        }

        return newFields;

    }

    private List<String> getValidatedFieldList()
    {
        // Retreive the existing field list
        List<String> existingFields = entry.Transaction_Field_List__c.split(';');

        // Get the map of existing fields on the Object
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Ledger_Entry__c.fields.getMap();

        // Validate each field
        for(String fieldName: existingFields)
        {
            // This would happen is someone deleted a field - which invalidates the chain
            if(!fieldMap.containsKey(fieldName)) return null;
        }

        return existingFields;

    }

    private String getTransactionHash(List<String> fieldList)
    {
        // Now buld the hash string
        String stringToHash = '';
        for(String fieldName: fieldList)
        {
            Object fieldValue = entry.get(fieldName);
            String fieldString;
            // Always format decimals as doubles for consistency
            if(fieldValue instanceof Decimal) 
                fieldString = String.valueOf((double)fieldValue);
            else fieldString = String.valueOf(fieldValue);
            stringToHash+= String.valueOf(fieldString);
        }
        Blob b = Blob.valueOf(stringToHash);
        Blob hash = Crypto.generateDigest('SHA-256', b);
       return EncodingUtil.base64Encode(hash);
    }


    public void setTransactionHash()
    {
        entry.Transaction_Hash__c = null;
        List<String> validFields = getNewFieldList();
        if(validFields==null) return;
        // Store the current string list
        entry.Transaction_Field_List__c = String.Join(validFields,';');
        entry.Transaction_Date__c = DateTime.now();
        
        entry.Transaction_Hash__c = GetTransactionHash(validFields);
    }

    public Boolean isTransactionHashValid()
    {
        List<String> existingFields = getValidatedFieldList();
        if(existingFields == null) return false;

        return entry.Transaction_Hash__c == GetTransactionHash(existingFields);
    }


}
