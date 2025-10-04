namespace eShopModernized.ViewModels;

public class PaginatedItemsViewModel<TEntity> where TEntity : class
{
    public int PageIndex { get; }
    public int PageSize { get; }
    public long Count { get; }
    public IEnumerable<TEntity> Data { get; }

    public PaginatedItemsViewModel(int pageIndex, int pageSize, long count, IEnumerable<TEntity> data)
    {
        PageIndex = pageIndex;
        PageSize = pageSize;
        Count = count;
        Data = data;
    }

    public bool HasPreviousPage => PageIndex > 0;
    public bool HasNextPage => (PageIndex + 1) * PageSize < Count;
    public int TotalPages => (int)Math.Ceiling(Count / (double)PageSize);
}