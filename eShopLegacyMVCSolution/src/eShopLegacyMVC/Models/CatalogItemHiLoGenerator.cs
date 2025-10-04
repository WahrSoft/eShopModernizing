using eShopLegacyMVC.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Internal;
using System;
using System.Linq;

namespace eShopLegacyMVC.Models
{
    public class CatalogItemHiLoGenerator
    {
        private const int HiLoIncrement = 10;
        private int sequenceId = -1;
        private int remainingLoIds = 0;
        private readonly object sequenceLock = new object();

        public int GetNextSequenceValue(CatalogDBContext db)
        {
            lock (sequenceLock)
            {
                if (remainingLoIds == 0)
                {

                    using var command = db.Database.GetDbConnection().CreateCommand();
                    command.CommandText = $"SELECT NEXT VALUE FOR catalog_hilo";

                    db.Database.OpenConnection();
                    try
                    {
                        var result = command.ExecuteScalar();
                        sequenceId = Convert.ToInt32(result);
                        remainingLoIds = HiLoIncrement - 1;
                    }
                    finally
                    {
                        db.Database.CloseConnection();
                    }

                    return sequenceId;
                }
                else
                {
                    remainingLoIds--;
                    return ++sequenceId;
                }
            }
        }
    }
}