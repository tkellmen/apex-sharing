trigger ProgramTrigger on Program__c(after update) {
	List<Program__c> reassigned_owner_programs = new List<Program__c>();
	Set<id> account_ids_without_permission = new Set<id>();
	Set<id> all_owners = new Set<id>();

	List<AccountShare> accountshares_to_insert = new List<AccountShare>();
	List<AccountShare> accountshares_to_delete = new List<AccountShare>();

	Map<id, Set<id>> available_account_by_id = new Map<id, Set<id>>();

	if (Trigger.isUpdate) {
		for (Program__c program_new : Trigger.new) {
			if (program_new.OwnerId != Trigger.oldMap.get(program_new.id).OwnerId) {
				// Todo add check if profile is Calling

				reassigned_owner_programs.add(program_new);
				all_owners.add(program_new.OwnerId);
				all_owners.add(Trigger.oldMap.get(program_new.id).OwnerId);
			}
		}

		for (Program__c program_with_reassigned_owner : [
			SELECT id, name, OwnerId, (SELECT id, name, Target_Company__c FROM Program_Target_Companies__r)
			FROM Program__c
			WHERE id IN :reassigned_owner_programs
		]) {
			for (Program_Target_Company__c target : program_with_reassigned_owner.Program_Target_Companies__r) {
				if (!account_ids_without_permission.contains(target.Target_Company__c)) {
					account_ids_without_permission.add(target.Target_Company__c);

					accountshares_to_insert.add(
						new AccountShare(
							AccountId = target.Target_Company__c,
							UserOrGroupId = program_with_reassigned_owner.OwnerId,
							AccountAccessLevel = 'Edit',
							OpportunityAccessLevel = 'Edit',
							RowCause = 'Manual'
						)
					);
				}
			}
		}

		insert accountshares_to_insert;

		for (Program_Target_Company__c program_with_available_target_company : [
			SELECT id, Name, Target_Company__c, Program__c.OwnerId
			FROM Program_Target_Company__c
			WHERE Target_Company__c IN :account_ids_without_permission AND Program__c.OwnerId IN :all_owners
		]) {
			if (!available_account_by_id.containsKey(program_with_available_target_company.Program__c.OwnerId)) {
				available_account_by_id.put(
					program_with_available_target_company.Program__c.OwnerId,
					new Set<Id>(Target_Company__c)
				);
			} else {
				available_account_by_id.get(program_with_available_target_company.Program__c.OwnerId)
					.add(Target_Company__c);
			}
		}

		for (id owner_id : available_account_by_id.keySet()) {
			for (
				id acc_to_remove : account_ids_without_permission.clone()
					.removeAll(available_account_by_id.get(owner_id))
			) {
				AccountShare AccShr = new AccountShare();

				AccShr.AccountId = recordId;
				AccShr.UserOrGroupId = owner_id;
				AccShr.AccountAccessLevel = 'Edit';
				AccShr.OpportunityAccessLevel = 'Edit';
				AccShr.RowCause = 'Manual';
				accountshares_to_delete.add(AccShr);
			}
		}
		insert accountshares_to_delete;
		delete accountshares_to_delete;
	}
}
