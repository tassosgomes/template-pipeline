using Xunit;

namespace Fixture.Tests;

public class CalcTests
{
    [Fact]
    public void SomaDoisInteiros()
    {
        Assert.Equal(5, Calc.Soma(2, 3));
    }

    [Fact]
    public void MontaQueryComNome()
    {
        Assert.Contains("maria", Insecure.BuscarUsuario("maria"));
    }
}
