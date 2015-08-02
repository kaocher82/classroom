class GroupAssignmentInvitation < ActiveRecord::Base
  has_one :grouping,     through: :group_assignment
  has_one :organization, through: :group_assignment

  has_many :groups, through: :grouping

  belongs_to :group_assignment

  validates :group_assignment, presence: true

  validates :key, presence:   true
  validates :key, uniqueness: true

  after_initialize :assign_key

  def redeem_for(invitee, selected_group = nil, new_group_title = nil)
    repo_access    = RepoAccess.find_or_create_by!(user: invitee, organization: organization)
    invitees_group = group(repo_access, selected_group, new_group_title)

    invitees_group.repo_accesses << repo_access unless invitees_group.repo_accesses.include?(repo_access)

    invitees_group_assignment_repo     = group_assignment_repo(invitees_group)
    group_assignment_github_repository = GitHubRepository.new(organization.github_client,
                                                              invitees_group_assignment_repo.github_repo_id)

    group_assignment_github_repository.full_name
  end

  def to_param
    key
  end

  protected

  def assign_key
    self.key ||= SecureRandom.hex(16)
  end

  private

  # Internal
  #
  def group(repo_access, selected_group, new_group_title)
    group = Group.joins(:repo_accesses).find_by(grouping: grouping, repo_accesses: { id: repo_access.id })

    return group if group.present?
    return selected_group if selected_group

    Group.create(title: new_group_title, grouping: grouping)
  end

  # Internal
  #
  def group_assignment_repo(invitees_group)
    group_assignment_params = { group_assignment: group_assignment, group: invitees_group }
    repo                    = GroupAssignmentRepo.find_by(group_assignment_params)

    return repo if repo

    GroupAssignmentRepo.create(group_assignment_params)
  end
end