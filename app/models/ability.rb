# frozen_string_literal: true

# CanCanCan Ability class for authorization

class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the user here. For example:
    #
    #   return unless user.present?
    #   can :read, :all
    #   return unless user.admin?
    #   can :manage, :all
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, published: true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/blob/develop/docs/define_check_abilities.md

    user ||= User.new

    if user.landlord?
      landlord_abilities(user)
    elsif user.tenant?
      tenant_abilities(user)
      # else
      #   guest_abilities
    end
  end

  private

  def landlord_abilities(user)
    id = user.id
    can :read, :dashboard
    can :manage, House, landlord_id: id
    # 2-level relations
    can :manage, [ Floor, Service ], house: { landlord_id: id }
    # 3-level relations
    can :manage, [ Room, Bed, RoomService ], house: { landlord_id: id }

    # can :manage, Floor, house: { landlord_id: id }
    # can :manage, Room, house: { landlord_id: id }
    # can :manage, Bed, room: { house: { landlord_id: id } }
    # can :manage, RoomService, room: { house: { landlord_id: id } }
    # can :manage, Service, house: { landlord_id: id }
    # can :manage, Invoice, room: { house: { landlord_id: user.id } }
    # can :manage, Vehicle, room: { house: { landlord_id: user.id } }
    # can :manage, Contract, room: { house: { landlord_id: user.id } }
  end

  def tenant_abilities(user)
    can :read, House
    can :read, Floor
    can :read, Room
    can :read, Bed
    can :read, RoomService
    can :read, Service
    # can :read, Invoice
    # can :read, Vehicle
    # can :read, Contract
  end

  # def guest_abilities
  #   can :read, Post
  # end
end
