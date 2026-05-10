module Api
  class CompetitorSetMembersController < BaseController
    # POST /api/competitor_sets/:competitor_set_id/members
    # Body: { restaurant_id, source? }
    def create
      set = CompetitorSet.find(params[:competitor_set_id])
      restaurant_id = params.require(:restaurant_id)
      source = params[:source].presence || "manual"

      member = CompetitorSetMember
                 .where(competitor_set_id: set.id, restaurant_id: restaurant_id)
                 .first_or_initialize
      member.update!(source: source, added_at: Time.current, removed_at: nil)

      render json: { member: member_payload(member) }, status: :created
    end

    # DELETE /api/competitor_sets/:competitor_set_id/members/:id
    def destroy
      member = CompetitorSetMember.find_by!(
        competitor_set_id: params[:competitor_set_id],
        id:                params[:id]
      )
      member.update!(removed_at: Time.current)
      head :no_content
    end

    private

    def member_payload(m)
      { id: m.id, competitor_set_id: m.competitor_set_id,
        restaurant_id: m.restaurant_id, source: m.source,
        added_at: m.added_at, removed_at: m.removed_at }
    end
  end
end
