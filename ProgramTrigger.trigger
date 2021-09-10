trigger ProgramTrigger on Program__c(after insert, after update) {
	List<Program__c> subscribe_owner = new List<Program__c>();
	List<Program__c> unsubscribe_owner = new List<Program__c>();
	Set<id> accounts_id_to_insert = new Set<id>();

	Set<id> all_owners = new Set<id>();

	List<AccountShare> CompanySharingList = new List<AccountShare>();

	if (Trigger.isUpdate) {
		for (Program__c program_new : Trigger.new) {
			if (program_new.OwnerId != Trigger.oldMap.get(program_new.id).OwnerId) {
				// add check on profile
				subscribe_owner.add(program_new);
				unsubscribe_owner.add(Trigger.oldMap.get(program_new.id));

				all_owners.add(program_new.OwnerId);
				all_owners.add(Trigger.oldMap.get(program_new.id).OwnerId);
			}
		}

		for (Program__c singel_target : [
			SELECT id, name, (SELECT id, name, Target_Company__c FROM Program_Target_Companies__r)
			FROM Program__c
			WHERE id IN :subscribe_owner
		]) {
			for (Program_Target_Company__c target : singel_target.Program_Target_Companies__r) {
				if (!accounts_id_to_insert.contains(target.Target_Company__c)) {
					accounts_id_to_insert.add(target.Target_Company__c);
					System.debug(target.name);
					//ми не знаємо чи було раніше заасайнено на цього юзера компанію

					CompanySharingList.add(
						new AccountShare(
							AccountId = target.Target_Company__c,
							UserOrGroupId = singel_target.OwnerId,
							AccountAccessLevel = 'Edit',
							OpportunityAccessLevel = 'Edit',
							RowCause = 'Manual'
						)
					);
				}
			}
		}

		insert CompanySharingList;

		// Remove

		set<id> lets = new Set<id>();

		Map<id, Set<id>> owners_with_available_account = new Map<id, Set<id>>();

		//Вибираємо

		for (Program_Target_Company__c program_with_available_target_company : [
			SELECT id, Name, Target_Company__c, Program__c.OwnerId
			FROM Program_Target_Company__c
			WHERE Target_Company__c IN :accounts_id_to_insert AND Program__c.OwnerId IN :all_owners
		]) {
			if (!owners_with_available_account.containsKey(program_with_available_target_company.Program__c.OwnerId)) {
				owners_with_available_account.put(
					program_with_available_target_company.Program__c.OwnerId,
					new Set<Id>(Target_Company__c)
				);
			} else {
				owners_with_available_account.get(program_with_available_target_company.Program__c.OwnerId)
					.add(Target_Company__c);
			}
		}

		Map<id, Set<id>> owners_with_remove_accounts = new Map<id, Set<id>>();

		List<AccountShare> deleteAccountShare = new List<AccountShare>();

		for (id owner_id : owners_with_available_account.keySet()) {
			for (
				id acc_to_remove : accounts_id_to_insert.clone().removeAll(owners_with_available_account.get(owner_id))
			) {
				AccountShare AccShr = new AccountShare();

				AccShr.AccountId = recordId;
				AccShr.UserOrGroupId = owner_id;
				AccShr.AccountAccessLevel = 'Edit';
				AccShr.OpportunityAccessLevel = 'Edit';

				AccShr.RowCause = 'Manual';

				deleteAccountShare.add(AccShr);
			}
		}
		insert deleteAccountShare;
		delete deleteAccountShare;
	}
}
