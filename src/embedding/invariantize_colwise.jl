#############################################################
# Making sure embedding is invariant under forward linear map
# of its vertices
#############################################################
import Simplices.Delaunay.delaunay
using Distributions
using Statistics: std

function forwardlinearmap_invariant(pts::Array{T, 2}) where {T <: Number}
    lastpoint = pts[:, end]
    dim = size(pts, 1)
    # Triangulate the embedding using all points but the last
    # Returns a vector of index vectors, one for each simplex
    t = delaunay(transpose(pts[:, 1:end-1]))
    n_simplices = length(t)
    points = pts[:, 1:end-1]

    # Loop over valid simplices and check whether the corresponding simplex
    # contains the last point.
    i = 1
    lastpoint_contained = false

    #=
    Continue checking if simplices contain the last point until some simplex
    contains it. Then the point must necessarily be inside the convex hull of
    the triangulation formed by those simplices.
    =#
    while i <= n_simplices && !lastpoint_contained
        sᵢ = transpose(points[:, t[i]])
        orientation_sᵢ = det([ones(dim + 1, 1) sᵢ])

        # Insert the last point of the embedding in place
        # of the j-th vertex of sᵢ and check whether the
        # convex expansion coefficient β𝚥 stays non-negative.
        # If β𝚥 becomes negative, the point is not contained.
        j = 1
        β𝚥 = 1
        while j <= dim + 1 && β𝚥 >= 0
            tmp = copy(sᵢ)
            tmp[j, :] = lastpoint
            β𝚥 = det(hcat(ones(dim + 1, 1), tmp)) * sign(orientation_sᵢ)
            j = j + 1
        end

        #=
        If the last convex expansion coefficient is positive, the last point is
        contained in the triangulation (because all the previous coefficients
        must have been nonnegative)
        =#
        if β𝚥 >= 0
            lastpoint_contained = true
        end

        i = i + 1
    end
    return lastpoint_contained
end

function invariantize(E::Embeddings.AbstractEmbedding;
                        verbose = false,
                        noise_factor = 0.01, step = 5)
   pts = E.points
   #@warn """Adding some noise to the points."""
   σ = std(E.points, dims = 2)
   dim = size(pts, 1)
   for i = 1:dim
      pts[i, :] .+= rand(Uniform(-σ[i], σ[i])) .* noise_factor
   end

   if size(unique(pts, dims = 2), 2) < size(pts, 2)

      @warn """Embedding points not unique. Adding a little noise ($noise_factor
            times the maximum of the the standard deviations along each axis)"""
      # Find standard deviation along each axis
      dim = size(pts, 1)
      for i = 1:dim
         pts[i, :] .+= rand(Uniform(-σ[i], σ[i])) .* noise_factor
      end
   end

   #=
   # Keep track of the embedding's center point and the original position of the
   # last point in the embedding, so we can move the last point along a line
   # from its original position towards the embedding's center, until the point
   # lies inside the convex hull of the preceding points.
   =#
   ce = sum(E.points, dims = 2)/size(E.points, 2) # embedding center
   lp = E.points[:, end] # last point of the embedding
   # What direction should we move?
   dir = ce - lp

   dir = dropdims(ce .- lp, dims = 2)

   # Points along line toward the center of the embedding.
   steps = 1:step:100
   ptsonline = [lp .+ dir .* (pct_moved/100) for pct_moved in 1:step:100]

   for i = 1:length(ptsonline)
      pt = ptsonline[i]
      P = hcat(pts[:, 1:(end - 1)], pt)
      #println(i, " ", steps[i] , " ",
      #forwardlinearmap_invariant(P), " " ,ce .- pt)

      if forwardlinearmap_invariant(P)
         return LinearlyInvariantEmbedding(
               hcat(pts[:, 1:(end-1)], pt),
               E.embeddingdata
            )
      end
   end
   @warn """Could not make embedding invariant. Returning unmodified $E."""
   return E
end

export forwardlinearmap_invariant, invariantize
